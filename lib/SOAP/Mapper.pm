#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package SOAP::Mapper;

use strict;
use warnings;

use Data::Dumper;
use SOAP::Mapper::WSDL::Parser;
use SOAP::Mapper::Request;
use SOAP::Mapper::Response;
use SOAP::Mapper::Transport;

use XML::LibXML;


sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   $self->_read_wsdl;
   $self->_parse_wsdl;

   $self->{request} = SOAP::Mapper::Request->new;

   return $self;
}

sub req { shift->{request}; }
sub ua { shift->req->ua; }

sub transport { shift->{transport}; }
sub service { shift->{service}; }
sub wsdl { shift->{wsdl}; }
sub parser { shift->{parser}; }

sub _read_wsdl {
   my ($self) = @_;
   $self->{wsdl} = $self->transport->get($self->service);
}

sub _parse_wsdl {
   my ($self) = @_;
   $self->{parser} = SOAP::Mapper::WSDL::Parser->new(wsdl => $self->wsdl);
   $self->parser->parse;


#                 'operations' => {
#                                   'updateLoadBalancer' => {
#                                                           'input' => {
#                                                                        'ns' => 'tns',
#                                                                        'type' => 'updateLoadBalancer'
#                                                                      },
#                                                           'output' => {
#                                                                         'ns' => 'tns',
#                                                                         'type' => 'updateLoadBalancerResponse'
#                                                                       },
#                                                           'fault' => {
#                                                                        'ns' => 'tns',
#                                                                        'type' => 'ProfitbricksServiceFault'
#                                                                      }
#                                                         },

   my $ops   = $self->parser->get_operations;
   my $types = $self->parser->get_types;

   for my $op_str (keys %{ $ops }) {
      no strict 'refs';

      my $op = $ops->{$op_str};

      *{ __PACKAGE__ . "::$op_str" } = sub {
         my ($local_self, %params) = @_;
         #print "Called: $op_str\n";

         my @code_params = $self->_construct_params($op->{input}->{type});

         for my $p (keys %params) {
            if(! grep { $_->{name} eq $p } @code_params) {
               die("Wrong parameter: $p");
            }
         }

         my $xml = $self->_create_envelope;

         my $elem = $xml->createElement($op->{input}->{ns} . ":" . $op->{input}->{type});

         my ($soap_body) = $xml->findnodes('//env:Body');
         $soap_body->appendChild($elem);

         # append parameters to xml
         for my $p (keys %params) {
            my $new_elem = $xml->createElement($p);
            $new_elem->appendTextNode($params{$p});
            $elem->appendChild($new_elem);
         }

         # fire request
         my $ret = eval {
            my $returned_content = $self->req->request($self->parser->get_endpoint, $op_str, $xml);
            my $response = SOAP::Mapper::Response->new;
            my $return = $response->parse($op->{output}, $returned_content);

            if($op->{output}->{type} eq $return->{type}) {
               return $return->{data};
            }
            else {
               die("Returned unknown type.");
            }
         } or do {
            die($@);
         };

         if(wantarray) {
            return @{ $ret };
         }

         return $ret;

      };

      use strict;
   }
}

sub list_operations {
   my ($self) = @_;
   print "$_\n" for keys %{ $self->parser->get_operations };
}

# my @params = $self->_construct_params('updateLoadBalancer', $types);
sub _construct_params {
   my ($self, $type, $types, $name) = @_;
   $types //= $self->parser->get_types;

   # this call need no parameter
   if(! exists $types->{$type} || ! exists $types->{$type}->{type}) {
      return ();
   }

   my $input = $types->{$type};

   my @ret = ();

   if($input->{type} eq "complexType") {

      for my $elem (@{ $input->{elements} }) {
         if($elem->{ns} ne "xs" && $elem->{name} ne "return") {
            push(@ret, $self->_construct_params($elem->{type}, $types, $elem->{name}));
         }
         else {
            push(@ret, { name => $elem->{name}, type => $elem->{type} });
         }
      }

   }

   elsif($input->{type} eq "simpleType") {
      if(exists $input->{restrictions}) {
         my @restrictions = ();
         for my $restr (@{ $input->{restrictions} }) {
            push(@restrictions, $restr->{value});
         }

         push(@ret, { name => $name, type => $input->{base}->{type}, restrictions => \@restrictions });
      }
   }

   return @ret;
}

sub _create_envelope {
   my ($self) = @_;

   my $envelope_xml = '<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope
   xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
   xmlns:tns="' . $self->parser->get_target_namespace . '"
   xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
   ';

   $envelope_xml .= '<env:Body/>';

   $envelope_xml .= '
</env:Envelope>
   ';

   return XML::LibXML->load_xml(string => $envelope_xml);
}
1;
