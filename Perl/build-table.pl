#!/usr/bin/env perl
#####################################################################
##  build-table.pl
##
##  Raymond Wan
##  https://github.com/rwanwork
##
##  Copyright (C) 2023, All rights reserved.
#####################################################################

use FindBin;
use lib $FindBin::Bin;  ##  Search the directory where the script is located

use diagnostics;
use strict;
use warnings;

##  Include library for handling arguments and documentation
use AppConfig;
use AppConfig::Getopt;
use Pod::Usage;


########################################
##  Important variables
########################################

sub cleanSize {
  my ($old_size) = @_;

  my $new_size = "";
  if ($old_size =~ /^(.+)K$/) {
    $new_size = $1 / 1024 / 1024;
  }
  elsif ($old_size =~ /^(.+)M$/) {
    $new_size = $1 / 1024;
  }
  elsif ($old_size =~ /^(.+)G$/) {
    $new_size = $1;
  }
  elsif ($old_size =~ /^(.+)T$/) {
    $new_size = $1 * 1024;
  }
  else {
    printf STDERR "EE\tUnable to match the size %s!\n", $old_size;
    exit (1);
  }
  
  return ($new_size);
}


########################################
##  Important variables
########################################

##  Input arguments
my $table_arg = "";


########################################
##  Process arguments
########################################

##  Create AppConfig and AppConfig::Getopt objects
my $config = AppConfig -> new ({
  GLOBAL => {
    DEFAULT => undef,      ##  Default value for new variables
  }
});

my $getopt = AppConfig::Getopt -> new ($config);

##  General program options
$config -> define ("verbose", {
  DEFAULT  => 0,
  ARGCOUNT => AppConfig::ARGCOUNT_ONE,
  ARGS => "=i"
});                        ##  Verbose output
$config -> define ("help!", {
  ARGCOUNT => AppConfig::ARGCOUNT_NONE
});                        ##  Help screen

##  Program parameters
$config -> define ("table", {
  ARGCOUNT => AppConfig::ARGCOUNT_ONE,
  ARGS => "=s"
});                        ##  Input table

##  Process the command-line options
$config -> getopt ();


########################################
##  Validate the settings
########################################

if ($config -> get ("help")) {
  pod2usage (-verbose => 0);
  exit (1);
}

if (!defined ($config -> get ("table"))) {
  printf STDERR "EE\tThe option --table requires a path to the input table.\n";
  exit (1);
}
$table_arg = $config -> get ("table");


########################################
##  Read in the table of input files
########################################

my @table_files;
my $num_table_files = 0;

open (my $table_fp, "<", $table_arg) or die "EE\tCould not open $table_arg for input!\n";
while (<$table_fp>) {
  my $line = $_;
  chomp ($line);
  
  push (@table_files, $line);
}
close ($table_fp);


########################################
##  Read in each input file, obtaining a list of users
########################################

my %set_logins;
my $num_unique_logins = 0;

for (my $k = 0; $k < scalar (@table_files); $k++) {
  my $curr_line = $table_files[$k];
  my ($curr_name, $curr_path) = split /\t/, $curr_line;
  
  if (!-e ($curr_path)) {
    printf STDERR "EE\tThe file %s could not be found!\n", $curr_path;
    exit (1);
  }
  
  open (my $curr_fp, "<", $curr_path) or die "EE\tThe file $curr_path could not be opened for input!\n";
  while (<$curr_fp>) {
    my $line = $_;
    chomp ($line);
    
    my ($size, $path) = split /\t/, $line;
    my $login = "";
    if ($path =~ /.*\/([^\/]+)$/) {
      $login = $1;
    }
    else {
      printf STDERR "EE\tCould not find the login name in %s!\n", $path;
      exit (1);
    }

    if (!defined ($set_logins{$login})) {
      $set_logins{$login} = 1;
      $num_unique_logins++;
    }
  }
  close ($curr_fp);
}

printf STDERR "II\tNumber of unique logins:  %u\n", $num_unique_logins;


########################################
##  Read in each input file, storing the sizes
########################################

my %store_sizes;
my @list_of_names;  ##  List of names, in the order that we want printed

for (my $k = 0; $k < scalar (@table_files); $k++) {
  my $curr_line = $table_files[$k];
  my ($curr_name, $curr_path) = split /\t/, $curr_line;

  push (@list_of_names, $curr_name);
  
  if (!-e ($curr_path)) {
    printf STDERR "EE\tThe file %s could not be found!\n", $curr_path;
    exit (1);
  }

  ##  Initialise for every possible user
  foreach my $key (keys %set_logins) {
    $store_sizes{$key}{$curr_name} = 0;
  }
  
  open (my $curr_fp, "<", $curr_path) or die "EE\tThe file $curr_path could not be opened for input!\n";
  while (<$curr_fp>) {
    my $line = $_;
    chomp ($line);
    
    my ($size, $path) = split /\t/, $line;
    my $login = "";
    if ($path =~ /.*\/([^\/]+)$/) {
      $login = $1;
    }
    else {
      printf STDERR "EE\tCould not find the login name in %s!\n", $path;
      exit (1);
    }
    
    $size = cleanSize ($size);
    
    $store_sizes{$login}{$curr_name} = $size;    
  }
  close ($curr_fp);
}

printf STDERR "II\tNumber of unique names:  %u\n", scalar (@list_of_names);


########################################
##  Output the table
########################################

for (my $j = 0; $j < scalar (@list_of_names); $j++) {
  printf STDOUT "\t%s", $list_of_names[$j];
}
printf STDOUT "\n";

foreach my $key (sort (keys %set_logins)) {
  printf STDOUT "%s", $key;
  for (my $j = 0; $j < scalar (@list_of_names); $j++) {
    my $curr_name = $list_of_names[$j];
    
    printf STDOUT "\t%.6f", $store_sizes{$key}{$curr_name};
  }

  printf STDOUT "\n";
}


