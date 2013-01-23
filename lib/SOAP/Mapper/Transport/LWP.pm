#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package SOAP::Mapper::Transport::LWP;

use strict;
use warnings;

use Data::Dumper;
use SOAP::Mapper::Transport::Base;
use LWP::UserAgent;
use MIME::Base64;

use base qw(SOAP::Mapper::Transport::Base);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = $proto->SUPER::new(@_);

   bless($self, $proto);

   return $self;
}

sub get {
   my ($self, $url) = @_;
   
   my $ua = LWP::UserAgent->new;
   my $res = $ua->get($url);

   if ($res->is_success) {
      return $res->decoded_content;
   }
   else {
      die("Error getting $url");
   }
}

sub post {
   my ($self, $url, $data, $header) = @_;

   my $ua = LWP::UserAgent->new;

   my $auth_string = encode_base64($self->{auth}->{user} . ":" . $self->{auth}->{password});
   push(@{ $header }, "authorization", "Basic $auth_string");

   my $res = $ua->post($url, @{ $header }, Content => $data);

   if($res->is_success) {
      return $res->decoded_content;
   }
   else {
      die("Error sending request: " . $res->status_line);
   }
}

sub basic_auth {
   my ($self, $user, $password) = @_;

   $self->{auth} = {
      type => "basic",
      user => $user,
      password => $password,
   };
}

1;
