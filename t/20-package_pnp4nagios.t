#!/usr/bin/env perl

use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan( tests => 33 );

##################################################
# create our test site
my $site = TestUtils::create_test_site() or BAIL_OUT("no further testing without site");

##################################################
# execute some checks
my $tests = [
  { cmd => "/usr/bin/omd start $site" },

  # submit a forced check, so we have initial perf data
  { cmd => "/bin/su - $site -c './lib/nagios/plugins/check_http -H localhost -a omdadmin:omd -u /$site/nagios/cgi-bin/cmd.cgi -e 200 -P \"cmd_typ=7&cmd_mod=2&host=omd-$site&service=Dummy+Service&start_time=2010-11-06+09%3A46%3A02&force_check=on&btnSubmit=Commit\" -r \"Your command request was successfully submitted\"'", like => '/HTTP OK:/', sleep => 30 },

  { cmd => "/bin/su - $site -c 'lib/nagios/plugins/check_http -H localhost -u /$site/pnp4nagios -e 401'",                           like => '/HTTP OK:/' },
  { cmd => "/bin/su - $site -c 'lib/nagios/plugins/check_http -H localhost -a omdadmin:omd -u /$site/pnp4nagios -e 301'",           like => '/HTTP OK:/' },
  { cmd => "/bin/su - $site -c 'lib/nagios/plugins/check_http -H localhost -a omdadmin:omd -u /$site/pnp4nagios/index.php -e 302'", like => '/HTTP OK:/' },
  { cmd => "/bin/su - $site -c 'lib/nagios/plugins/check_http -H localhost -a omdadmin:omd -u /$site/pnp4nagios/graph?host=omd-$site -e 200'", like => '/HTTP OK:/' },

  { cmd => "/usr/bin/omd stop $site" },
];
for my $test (@{$tests}) {
    TestUtils::test_command($test);
}

##################################################
# cleanup test site
TestUtils::remove_test_site($site);