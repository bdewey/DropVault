#!/usr/bin/perl
use strict;
use warnings;

##
##  This script removes the DropBox API keys from a file. It's used prior to checkin to make sure
##  that the keys do not get submitted to source control.
##

while(<STDIN>) {
  s/^#define DROPVAULT_(\S*).*$/\/\/#define PHOLIO_$1 .../;
  print;
}