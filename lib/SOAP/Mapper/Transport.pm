#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package SOAP::Mapper::Transport;

use strict;
use warnings;

sub create {
   my ($class, $type) = @_;
   $type ||= "LWP";

   my $klass = "SOAP::Mapper::Transport::$type";
   eval "use $klass";

   if($@) {
      die("Unknown transport type. $klass");
   }

   return $klass->new;
}

1;
