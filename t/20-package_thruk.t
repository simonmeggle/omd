#!/usr/bin/env perl

use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan( tests => 364 );

##################################################
# create our test site
my $site    = TestUtils::create_test_site() or BAIL_OUT("no further testing without site");
my $auth    = 'OMD Monitoring Site '.$site.':omdadmin:omd';
my $host    = "omd-".$site;
my $service = "Dummy+Service";

# set thruk as default
TestUtils::test_command({ cmd => "/usr/bin/omd config $site set WEB thruk" });

##################################################
# define some checks
my $tests = [
  { cmd => "/bin/su - $site -c 'lib/nagios/plugins/check_http -H localhost -u /$site/thruk -e 401'",                    like => '/HTTP OK:/' },
  { cmd => "/bin/su - $site -c 'lib/nagios/plugins/check_http -H localhost -a omdadmin:omd -u /$site/thruk -e 301'",    like => '/HTTP OK:/' },
  { cmd => "/bin/su - $site -c 'lib/nagios/plugins/check_http -H localhost -a omdadmin:omd -u /$site/thruk/ -e 200'",   like => '/HTTP OK:/' },
  { cmd => "/bin/su - $site -c 'lib/nagios/plugins/check_http -H localhost -a omdadmin:omd -u \"/$site/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail\" -e 200 -r \"Host Status Details For All Host Groups\"'", like => '/HTTP OK:/' },
  { cmd => "/bin/su - $site -c 'lib/nagios/plugins/check_http -H localhost -a omdadmin:omd -u \"/$site/thruk/cgi-bin/tac.cgi\" -e 200 -r \"Logged in as <i>omdadmin<\/i>\"'", like => '/HTTP OK:/' },
];
my $urls = [
# static html pages
  { url => "",                       like => '/<title>Thruk<\/title>/' },
  { url => "/thruk/index.html",      like => '/<title>Thruk<\/title>/' },
  { url => "/thruk/docs/index.html", like => '/<title>Thruk Documentation<\/title>/' },
  { url => "/thruk/main.html",       like => '/<title>Thruk Monitoring Webinterface<\/title>/' },
  { url => "/thruk/side.html",       like => '/<title>Thruk<\/title>/' },

# availability
  { url => '/thruk/cgi-bin/avail.cgi', 'like' => '/Availability Report/' },
  { url => '/thruk/cgi-bin/avail.cgi?host='.$host.'&timeperiod=last7days&smon=1&sday=13&syear=2010&shour=0&smin=0&ssec=0&emon=1&eday=14&eyear=2010&ehour=24&emin=0&esec=0&rpttimeperiod=&assumeinitialstates=yes&assumestateretention=yes&assumestatesduringnotrunning=yes&includesoftstates=no&initialassumedservicestate=0&backtrack=4', 'like' => '/Availability Report/' },

# extinfo
  { url => '/thruk/cgi-bin/extinfo.cgi?type=1&host='.$host },
  { url => '/thruk/cgi-bin/extinfo.cgi?type=2&host='.$host.'&service='.$service },

# config
  { url => '/thruk/cgi-bin/config.cgi',               'like' => '/Configuration/' },
  { url => '/thruk/cgi-bin/config.cgi?type=hosts',    'like' => '/Configuration/' },
  { url => '/thruk/cgi-bin/config.cgi?type=services', 'like' => '/Configuration/' },

# history
  { url => '/thruk/cgi-bin/history.cgi',                                  like => '/Alert History/' },
  { url => '/thruk/cgi-bin/history.cgi?host=all',                         like => '/Alert History/' },
  { url => '/thruk/cgi-bin/history.cgi?host='.$host,                      like => '/Alert History/' },
  { url => '/thruk/cgi-bin/history.cgi?host='.$host.'&service='.$service, like => '/Alert History/' },

# notifications
  { url => '/thruk/cgi-bin/notifications.cgi', like => '/All Hosts and Services/' },

# outages
  { url => '/thruk/cgi-bin/outages.cgi', like => '/Network Outages/' },

# showlog
  { url => '/thruk/cgi-bin/showlog.cgi', like => '/Event Log/' },

# status
  { url => '/thruk/cgi-bin/status.cgi',             like => '/Current Network Status/' },
  { url => '/thruk/cgi-bin/status.cgi?host='.$host, like => '/Current Network Status/' },

# summary
  { url => '/thruk/cgi-bin/summary.cgi', like => '/Alert Summary Report/' },

# tac
  { url => '/thruk/cgi-bin/tac.cgi', like => '/Tactical Monitoring Overview/' },

# trends
  { url => '/thruk/cgi-bin/trends.cgi?host='.$host.'&t1=1264820912&t2=1265425712&includesoftstates=no&assumestateretention=yes&assumeinitialstates=yes&assumestatesduringnotrunning=yes&initialassumedhoststate=0&backtrack=4', 'like'  => '/Host and Service State Trends/' },
  { url => '/thruk/cgi-bin/trends.cgi?host='.$host.'&service='.$service.'&t1=1264820912&t2=1265425712&includesoftstates=no&assumestateretention=yes&assumeinitialstates=yes&assumestatesduringnotrunning=yes&initialassumedservicestate=0&backtrack=4', 'like' => '/Host and Service State Trends/' },
];

##################################################
# run our tests
TestUtils::test_command({ cmd => "/usr/bin/omd start $site" });
TestUtils::test_command({ cmd => "/bin/su - $site -c './lib/nagios/plugins/check_http -H localhost -a omdadmin:omd -u /$site/nagios/cgi-bin/cmd.cgi -e 200 -P \"cmd_typ=7&cmd_mod=2&host=omd-$site&service=Dummy+Service&start_time=2010-11-06+09%3A46%3A02&force_check=on&btnSubmit=Commit\" -r \"Your command request was successfully submitted\"'", like => '/HTTP OK:/' });
sleep(30);
for my $test (@{$tests}) {
    TestUtils::test_command($test);
}
##################################################
# and request some pages
for my $url ( @{$urls} ) {
    $url->{'url'}    = "http://localhost/".$site.$url->{'url'};
    $url->{'auth'}   = $auth;
    $url->{'unlike'} = '/internal server error/';
    TestUtils::test_url($url);
}

##################################################
# switch webserver to shared mode
TestUtils::test_command({ cmd => "/usr/bin/omd stop $site" });
TestUtils::test_command({ cmd => "/usr/bin/omd config $site set WEBSERVER shared" });
TestUtils::test_command({ cmd => "/etc/init.d/apache2 reload" });
TestUtils::test_command({ cmd => "/usr/bin/omd start $site" });

##################################################
# then run tests again
for my $test (@{$tests}) {
    TestUtils::test_command($test);
}
##################################################
# and request some pages
for my $url ( @{$urls} ) {
    $url->{'auth'}   = $auth;
    $url->{'unlike'} = '/internal server error/';
    TestUtils::test_url($url);
}

##################################################
# cleanup test site
TestUtils::remove_test_site($site);