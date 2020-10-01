#! /usr/bin/perl	-- -*- coding: utf-8 -*-

use utf8;
use Encode;
use MP3::Tag;

$debug = 1;
$verbose = 1;

my $filename = "33.mp3";

$mp3 = MP3::Tag->new($filename);
$mp3->close();
exit(0);
