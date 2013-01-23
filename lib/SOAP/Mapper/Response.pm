#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package SOAP::Mapper::Response;

use strict;
use warnings;

use XML::XPath;
use Data::Dumper;
use XML::LibXML;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub xp { shift->{xp}; }

sub parse {
   my ($self, $want_return, $xml) = @_;

   my $xml_response = XML::LibXML->load_xml( string => $xml );
   my $envelope_ns = $self->_envelope_ns($xml_response);

   my $body = $xml_response->findnodes("//$envelope_ns:Body")->shift;

   my $answer = $body->firstChild;
   my ($answer_ns, $answer_type) = split(/:/, $answer->getName);
   my $answer_ns_uri =  $answer->getAttribute("xmlns:$answer_ns");

   my $return = {
      type => $answer_type,
      ns   => $answer_ns,
      data => [],
   };

   for my $return_node ($answer->childNodes()) {
      my $node_data = {};

      for my $node ($return_node->childNodes()) {
         $node_data->{$node->nodeName()} = $node->textContent();
      }

      push(@{ $return->{data} }, $node_data);
   }

   return $return;
}

sub _envelope_ns {
   my ($self, $xml) = @_;
   my %map
      = map {$_->name =~ /^xmlns:?(.*)$/; ($_->value => $1)}
         grep { $_->name =~ /^xmlns/ } $xml->firstChild->getAttributes;

   return $map{'http://schemas.xmlsoap.org/soap/envelope/'};
}

1;
