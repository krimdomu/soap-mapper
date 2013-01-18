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


sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   $self->_read_wsdl;
   $self->_parse_wsdl;

   return $self;
}

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

   print Dumper($self->parser->{types});
}



1;
