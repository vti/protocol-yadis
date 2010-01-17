#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 10;

use Protocol::Yadis;

my $y = Protocol::Yadis->new(
    http_req_cb => sub {
        my ($url, $method, $headers, $body, $cb) = @_;

        my $status = 200;
        $body    = '';
        $headers = {};

        if ($url eq '1') {
            $status = 404;
        }
        elsif ($url eq '2') {
            $headers = {
                'X-XRDS-Location' => 'unknown',
                'Content-Type'    => 'application/xrds+xml'
            };
            $body =<<'';
<?xml version="1.0" encoding="UTF-8"?>
<xrds:XRDS xmlns:xrds="xri://$xrds" xmlns="xri://$xrd*($v*2.0)"
   xmlns:openid="http://openid.net/xmlns/1.0">
 <XRD>
  <Service priority="10">
   <Type>http://openid.net/signon/1.0</Type>
   <URI>http://www.myopenid.com/server</URI>
   <openid:Delegate>http://smoker.myopenid.com/</openid:Delegate>
  </Service>
 </XRD>
</xrds:XRDS>

        }
        elsif ($url eq '3') {
            $headers = {
                'X-XRDS-Location' => 'second',
                'Content-Type'    => 'text/html'
            };
        }
        elsif ($url eq '4') {
            $headers = {
                'X-XRDS-Location' => 'second'
            };
        }
        elsif ($url eq '5') {
        }
        elsif ($url eq '6') {
            $headers = {
                'Content-Type'    => 'application/xrds+xml'
            };
            $body =<<'';
<?xml version="1.0" encoding="UTF-8"?>
<xrds:XRDS xmlns:xrds="xri://$xrds" xmlns="xri://$xrd*($v*2.0)"
   xmlns:openid="http://openid.net/xmlns/1.0">
 <XRD>
  <Service priority="10">
   <Type>http://openid.net/signon/1.0</Type>
   <URI>http://www.myopenid.com/server</URI>
   <openid:Delegate>http://smoker.myopenid.com/</openid:Delegate>
  </Service>
 </XRD>
</xrds:XRDS>

        }
        elsif ($url eq '7') {
            $headers = {
                'Content-Type'    => 'text/html'
            };
            $body =<<'';
<html>
    <head>
        <meta http-equiv="X-XRDS-Location" content="second" />
    </head>
    <body>
    </body>
</html>

        }
        elsif ($url eq '8') {
            $headers = {
                'Content-Type'    => 'text/html'
            };
            $body =<<'';
<html>
    <head>
    </head>
    <body>
    </body>
</html>

        }
        elsif ($url eq '9') {
            $headers = {
                'Content-Type'    => 'text/html'
            };
            $body =<<'';
<html>
    <body>
    </body>
</html>

        }
        elsif ($url eq '10') {
            $headers = {
                'Content-Type'    => 'text/html'
            };
            $body = 'foobarbaz';
        }
        elsif ($url eq 'second') {
            $headers = {
                'Content-Type'    => 'application/xrds+xml'
            };
            $body =<<'';
<?xml version="1.0" encoding="UTF-8"?>
<xrds:XRDS xmlns:xrds="xri://$xrds" xmlns="xri://$xrd*($v*2.0)"
   xmlns:openid="http://openid.net/xmlns/1.0">
 <XRD>
  <Service priority="10">
   <Type>http://openid.net/signon/1.0</Type>
   <URI>http://www.myopenid.com/server</URI>
   <openid:Delegate>http://smoker.myopenid.com/</openid:Delegate>
  </Service>
 </XRD>
</xrds:XRDS>

        }

        $cb->($url, $status, $headers, $body);
    }
);

# !200 -> FAIL
$y->discover('1' => sub { ok(not defined $_[1]) });

# 200 -> X-XRDS-Location -> document -> yadis -> OK
$y->discover('2' => sub { ok($_[1]) });

# 200 -> X-XRDS-Location -> document -> !yadis -> FAIL
$y->discover('3' => sub { ok($_[1]) });

# 200 -> X-XRDS-Location -> !document -> SECOND
$y->discover('4' => sub { ok($_[1]) });

# 200 -> !X-XRDS-Location -> !document -> FAIL
$y->discover('5' => sub { ok(not defined $_[1]) });

# 200 -> !X-XRDS-Location -> document -> yadis -> OK
$y->discover('6' => sub { ok($_[1]) });

# 200 -> !X-XRDS-Location -> document -> html -> head -> meta -> SECOND
$y->discover('7' => sub { ok($_[1]) });

# 200 -> !X-XRDS-Location -> document -> html -> head -> !meta -> FAIL
$y->discover('8' => sub { ok(not defined $_[1]) });

# 200 -> !X-XRDS-Location -> document -> html -> !head -> FAIL
$y->discover('9' => sub { ok(not defined $_[1]) });

# 200 -> !X-XRDS-Location -> document -> !html && !yadis -> FAIL
$y->discover('10' => sub { ok(not defined $_[1]); });
