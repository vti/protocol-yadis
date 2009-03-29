use Test::More tests => 13;

use Protocol::Yadis;

my ($y, $document);

$y = Protocol::Yadis->new(
    http_req_cb => sub {
        my ($self, $url, $args, $cb) = @_;

        my $status = 200;
        my $headers = {};
        my $body;

        if ($url eq 'document') {
            $headers = {'Content-Type' => 'application/xrds+xml'};
            $body = <<'';
<?xml version="1.0" encoding="UTF-8"?>
<xrds:XRDS xmlns:xrds="xri://$xrds" xmlns="xri://$xrd*($v*2.0)"
   xmlns:openid="http://openid.net/xmlns/1.0">
 <XRD>
  <Service priority="10">
   <Type>http://openid.net/signon/1.0</Type>
   <URI>http://www.myopenid.com/server</URI>
   <openid:Delegate>http://smoker.myopenid.com/</openid:Delegate>
  </Service>
  <Service priority="50">
   <Type>http://openid.net/signon/1.0</Type>
   <Type>http://openid.net/signon/1.0</Type>
   <Type>http://openid.net/signon/1.0</Type>
   <URI>http://www.livejournal.com/openid/server.bml</URI>
   <openid:Delegate>
     http://www.livejournal.com/users/frank/
   </openid:Delegate>
  </Service>
  <Service priority="20">
   <Type>http://lid.netmesh.org/sso/2.0</Type>
   <URI>http://www.livejournal.com/openid/server.bml</URI>
   <URI>http://www.livejournal.com/openid/server.bml</URI>
  </Service>
  <Service>
   <Type>http://lid.netmesh.org/sso/1.0</Type>
   <URI>http://www.livejournal.com/openid/server.bml</URI>
  </Service>
  <Service>
   <URI>http://www.livejournal.com/openid/server.bml</URI>
  </Service>
 </XRD>
</xrds:XRDS>

        } elsif ($url eq 'document-no-body') {
            $headers = {'Content-Type' => 'application/xrds+xml'};
        } elsif ($url eq 'document-noservices') {
            $headers = {'Content-Type' => 'application/xrds+xml'};
            $body = <<'';
<?xml version="1.0" encoding="UTF-8"?>
<xrds:XRDS xmlns:xrds="xri://$xrds" xmlns="xri://$xrd*($v*2.0)"
   xmlns:openid="http://openid.net/xmlns/1.0">
 <XRD>
 </XRD>
</xrds:XRDS>

        } elsif ($url eq 'document-wrong') {
            $headers = {'Content-Type' => 'application/xrds+xml'};
            $body = 'foo';
        } elsif ($url eq 'header-location') {
            $headers = {'X-XRDS-Location' => 'document'};
        } elsif ($url eq 'header-location-recursive') {
            $headers = {'X-XRDS-Location' => 'header-location'};
        } elsif ($url eq 'header-location-not-found') {
            $headers = {'X-XRDS-Location' => 'not-found'};
        } elsif ($url eq 'html-location') {
            $body = <<'';
<html>
    <head>
        <meta http-equiv="X-XRDS-Location" content="document" />
        <meta http-equiv="X-XRDS-Location" content="not-found" />
    </head>
    <body>
    </body>
</html>

        } elsif ($url eq 'html-location2') {
            $body = <<'';
        <meta http-equiv="X-XRDS-Location" content="not-found" />
<html> <head> 
        <!-- meta http-equiv="X-XRDS-Location" content="not-found" -->
<MEta http-eqUIv=    "X-Xrds-lOCation" content    = 'document' />
    </head>
    <body>
    </body>
</html>

        } elsif ($url eq 'html-location-not-found') {
            $body = <<'';
<html>
    <head>
        <meta http-equiv="X-XRDS-Location" content="not-found" />
    </head>
    <body>
    </body>
</html>

        } elsif ($url eq 'html-no-location') {
            $body = <<'';
<html>
    <head>
    </head>
    <body>
    </body>
</html>

        } elsif ($url eq 'unknown-document') {
            $body = 'foo bar';
        } else {
            $status = 404;
        }

        $cb->($self => $url =>
              {status => $status, headers => $headers, body => $body});
    }
);

$y->discover('not-found', sub { is($_[1], 'error') });
$y->clear;

$y->discover('document', sub { is($_[1], 'ok') });
$y->clear;

$y->discover('document-no-body', sub { is($_[1], 'error') });
$y->clear;

$y->discover('document-noservices', sub { is($_[1], 'ok') });
$y->clear;

$y->discover('document-wrong', sub { is($_[1], 'error') });
$y->clear;

$y->discover('header-location', sub { is($_[1], 'ok') });
$y->clear;

$y->discover('header-location-not-found', sub { is($_[1], 'error') });
$y->clear;

$y->discover('header-location-recursive', sub { is($_[1], 'error') });
$y->clear;

$y->discover('html-location', sub { is($_[1], 'ok') });
$y->clear;

$y->discover('html-location2', sub { is($_[1], 'ok') });
$y->clear;

$y->discover('html-no-location', sub { is($_[1], 'error') });
$y->clear;

$y->discover('html-location-not-found', sub { is($_[1], 'error') });
$y->clear;

$y->discover('unknown-document', sub { is($_[1], 'error') });
$y->clear;
