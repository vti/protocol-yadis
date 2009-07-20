#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 3;

use Protocol::Yadis;

my $y = Protocol::Yadis->new(
    head_first => 1,
    http_req_cb => sub {
        my ($url, $method, $headers, $body, $cb) = @_;

        my $status = 200;
        $body    = '';
        $headers = {};

        if ($url eq '1') {
            $status = 404;
        }
        elsif ($url eq '2') {
            $headers = {'X-XRDS-Location' => 'second'};
        }
        elsif ($url eq '3') {
            $headers = {'X-XRDS-Location' => 'second'} if $method eq 'GET';
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
$y->discover('1' => sub {ok(not defined $_[1])});

# 200 -> X-XRDS-Location -> SECOND
$y->discover('2' => sub {ok($_[1])});

# 200 -> !X-XRDS-Location -> INITIAL
$y->discover('3' => sub {ok($_[1])});
