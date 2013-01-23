#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package SOAP::Mapper::WSDL::Parser;

use strict;
use warnings;

use XML::XPath;
use Data::Dumper;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   $self->{namespaces}     = [];
   $self->{operations}     = {};
   $self->{types}          = {};
   $self->{deferred_types} = [];
   $self->{endpoint}       = "";
   $self->{element_form_default} = undef;

   return $self;
}

sub parse {
   my ($self) = @_;

   $self->{xp} = XML::XPath->new(xml => $self->wsdl);

   $self->xp->set_namespace("xs"     => "http://www.w3.org/2001/XMLSchema");
   $self->xp->set_namespace("wsdl"   => "http://schemas.xmlsoap.org/wsdl/");
   $self->xp->set_namespace("soap11" => "http://schemas.xmlsoap.org/wsdl/soap/");
   $self->xp->set_namespace("soap12" => "http://schemas.xmlsoap.org/wsdl/soap12/");

   $self->parse_namespaces;
   $self->parse_operations;
   $self->parse_types;
   $self->parse_endpoint;
}

sub wsdl { shift->{wsdl}; }
sub xp { shift->{xp}; }

sub get_operations {
   my  ($self) = @_;
   return $self->{operations};
}

sub get_types {
   my  ($self) = @_;
   return $self->{types};
}

sub get_target_namespace {
   my ($self) = @_;
   return $self->{target_namespace};
}

sub get_endpoint {
   my ($self) = @_;
   return $self->{endpoint};
}

sub parse_endpoint {
   my ($self) = @_;

   my $x = $self->xp->find('wsdl:definitions/wsdl:service//soap11:address/@location')->shift;
   $x  ||= $self->xp->find('wsdl:definitions/wsdl:service//soap12:address/@location')->shift;

   $self->{endpoint} = $x->getValue;
}

sub parse_namespaces {
   my ($self) = @_;

   $self->{element_form_default} = $self->xp->getNodeText('wsdl:definitions/wsdl:types/xs:schema/@elementFormDefault')->value;

   my $x = $self->xp->find('wsdl:definitions/@targetNamespace')->shift;

   $self->{target_namespace} = $x->getValue;
}

sub parse_operations {
   my ($self) = @_;

   my $x = $self->xp->find('wsdl:definitions/wsdl:binding/wsdl:operation');

   for my $node ($x->get_nodelist) {
      my $soap_action = $self->xp->find('.//soap11:operation/@soapAction', $node);
      $soap_action  ||= $self->xp->find('.//soap12:operation/@soapAction', $node);

      if($soap_action) {
         $self->{operations}->{$node->getAttribute("name")} = {
            input  => $self->_get_input_for($node),
            output => $self->_get_output_for($node),
            fault  => $self->_get_fault_for($node),
         }; 
      }
      else {
         warn "Something unhandled happened...\n";
      }

   }

}

sub parse_types {
   my ($self) = @_;
   
   # complexTypes
   my $x = $self->xp->find('wsdl:definitions/wsdl:types/xs:schema/xs:complexType[@name]');

   for my $node ($x->get_nodelist) {
      my $type_name = $node->getAttribute("name");
      $self->{types}->{$type_name} = {};

      my $sequence_set = $self->xp->find('./xs:sequence/xs:element', $node);
      if($sequence_set->get_nodelist) {
         my @elements = ();
         for my $sequence ($sequence_set->get_nodelist) {
            my $elem_name = $sequence->getAttribute("name");
            my ($elem_ns, $elem_type) = split(/:/, $sequence->getAttribute("type"));
            push(@elements, { name => $elem_name, type => $elem_type, ns => $elem_ns });
         }

         $self->{types}->{$type_name} = {
            type => "complexType",
            elements => \@elements,
         };

         next;
      }

      my $complex_content_extension_set = $self->xp->find('./xs:complexContent/xs:extension[@base]', $node); 
      if($complex_content_extension_set && (my $complex_content_extension = $complex_content_extension_set->shift)) {
         my $extend_type = $complex_content_extension->getAttribute("base");

         my $sequence_set = $self->xp->find('./xs:sequence/xs:element', $complex_content_extension);
         if($sequence_set->get_nodelist) {
            my @elements = ();
            for my $sequence ($sequence_set->get_nodelist) {
               my $elem_name = $sequence->getAttribute("name");
               my ($elem_ns, $elem_type) = split(/:/, $sequence->getAttribute("type"));
               push(@elements, { name => $elem_name, type => $elem_type, ns => $elem_ns });
            }

            my ($base_ns, $base_type) = split(/:/, $extend_type);

            $self->{types}->{$type_name} = {
               type => "complexType",
               base => { ns => $base_ns, type => $base_type },
               elements => \@elements,
            };

            next;
         }

      }

   }

   # simpleTypes
   $x = $self->xp->find('wsdl:definitions/wsdl:types/xs:schema/xs:simpleType[@name]');

   for my $node ($x->get_nodelist) {
      my $type_name = $node->getAttribute("name");
      $self->{types}->{$type_name} = {};

      my $restriction_set = $self->xp->find('./xs:restriction[@base]', $node);
      if($restriction_set && (my $restriction = $restriction_set->shift)) {
         my ($base_ns, $base_type) = split(/:/, $restriction->getAttribute("base"));
         my $enum_set = $self->xp->find('./xs:enumeration', $restriction);

         my @restrictions = ();
         for my $enum ($enum_set->get_nodelist) {
            my $value = $enum->getAttribute("value");
            push(@restrictions, { value => $value });
         }
         $self->{types}->{$type_name} = {
            type => "simpleType",
            base => { ns => $base_ns, type => $base_type },
            restrictions => \@restrictions,
         };
      }

   }

}

sub _get_input_for {
   my ($self, $node) = @_;

   my $operation_name = $node->getAttribute("name");
   my $type_node = $self->xp->findvalue('../@type', $node);
   my $binding_type = [split(/:/, $type_node->value())]->[-1];

   my $port_type_input_set = $self->xp->find("../../wsdl:portType[\@name='$binding_type']/wsdl:operation[\@name='$operation_name']/wsdl:input", $node);

   if($port_type_input_set && (my $port_type_input = $port_type_input_set->shift)) {
      
      my ($port_message_ns_id, $port_message_type) = split(/:/, $port_type_input->getAttribute("message"));

      return { ns => $port_message_ns_id, type => $port_message_type };

   }
   else {
      warn "Unhandled Exception.\n";
      return { ns => undef, type => $operation_name };
   }
}

sub _get_output_for {
   my ($self, $node) = @_;

   my $operation_name = $node->getAttribute("name");
   my $type_node = $self->xp->findvalue('../@type', $node);
   my $binding_type = [split(/:/, $type_node->value())]->[-1];

   my $port_type_output_set = $self->xp->find("../../wsdl:portType[\@name='$binding_type']/wsdl:operation[\@name='$operation_name']/wsdl:output", $node);

   if($port_type_output_set && (my $port_type_output = $port_type_output_set->shift)) {
      
      my ($port_message_ns_id, $port_message_type) = split(/:/, $port_type_output->getAttribute("message"));

      return { ns => $port_message_ns_id, type => $port_message_type };

   }
   else {
      warn "Unhandled Exception.\n";
      return { ns => undef, type => $operation_name };
   }
}

sub _get_fault_for {
   my ($self, $node) = @_;

   my $operation_name = $node->getAttribute("name");
   my $type_node = $self->xp->findvalue('../@type', $node);
   my $binding_type = [split(/:/, $type_node->value())]->[-1];

   my $port_type_fault_set = $self->xp->find("../../wsdl:portType[\@name='$binding_type']/wsdl:operation[\@name='$operation_name']/wsdl:fault", $node);

   if($port_type_fault_set && (my $port_type_fault = $port_type_fault_set->shift)) {
      
      my ($port_message_ns_id, $port_message_type) = split(/:/, $port_type_fault->getAttribute("message"));

      return { ns => $port_message_ns_id, type => $port_message_type };

   }
   else {
      warn "Unhandled Exception.\n";
      return { ns => undef, type => $operation_name };
   }
}
1;
