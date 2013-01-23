#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package SOAP::Mapper::Request;

use strict;
use warnings;

use SOAP::Mapper::Transport;
use Data::Dumper;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   $self->{ua} = SOAP::Mapper::Transport->create;

   return $self;
}

sub request {
   my ($self, $url, $action, $xml) = @_;

   my $resp = $self->ua->post($url, $xml->toString(), [ SOAPAction => $action, "Content-Type" => "text/xml;charset=UTF-8" ]);
   return $resp;
}

sub ua { shift->{ua}; };


1;


__DATA__



: HTTPI GET request to api.profitbricks.com (net_http)
: https://api.profitbricks.com/1.2

: SOAPAction: "getAllDataCenters", Content-Type: text/xml;charset=UTF-8, Content-Length: 332

<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope 
   xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
   xmlns:tns="http://ws.api.profitbricks.com/" 
   xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
      <env:Body>
         <tns:getAllDataCenters></tns:getAllDataCenters>
      </env:Body>
</env:Envelope>

: HTTPI POST request to api.profitbricks.com (net_http)
: SOAP response (status 200)

<?xml version='1.0' encoding='UTF-8'?>
<S:Envelope 
   xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">
   <S:Body>
      <ns2:getAllDataCentersResponse xmlns:ns2="http://ws.api.profitbricks.com/">
         <return>
            <dataCenterId>4b791812-b73b-5bd6-64fd-2a0c78c8f6d8</dataCenterId>
            <dataCenterName>inovex-test02</dataCenterName>
            <dataCenterVersion>1</dataCenterVersion>
         </return>
         <return>
            <dataCenterId>bdef3ce8-8f69-1cd4-0932-ec62ebb4f418</dataCenterId>
            <dataCenterName>inovex Test RZ</dataCenterName>
            <dataCenterVersion>1</dataCenterVersion>
         </return>
      </ns2:getAllDataCentersResponse>
   </S:Body>
</S:Envelope>




: HTTPI GET request to api.profitbricks.com (net_http)
: SOAP request: https://api.profitbricks.com/1.2
: SOAPAction: "createDataCenter", Content-Type: text/xml;charset=UTF-8, Content-Length: 400

<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope
   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xmlns:tns="http://ws.api.profitbricks.com/"
   xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
   <env:Body>
      <tns:createDataCenter>
         <dataCenterName>My Test Center</dataCenterName>
         <region>EUROPE</region>
      </tns:createDataCenter>
   </env:Body>
</env:Envelope>


: HTTPI POST request to api.profitbricks.com (net_http)
: SOAP response (status 200)

<?xml version='1.0' encoding='UTF-8'?>
<S:Envelope 
   xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">
   <S:Body>
      <ns2:createDataCenterResponse xmlns:ns2="http://ws.api.profitbricks.com/">
         <return>
            <requestId>30129</requestId>
            <dataCenterId>2521696e-d735-43d3-b0d0-ab914561cf55</dataCenterId>
            <dataCenterVersion>1</dataCenterVersion>
            <region>EUROPE</region>
         </return>
      </ns2:createDataCenterResponse>
   </S:Body>
</S:Envelope>
#<Savon::Response:0x00000002e111d8>


