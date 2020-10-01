#! /usr/bin/perl	-- -*- coding: utf-8 -*-

use utf8;
use Encode;

#binmode STDIN,  ":encoding(cp932)";
#binmode STDOUT, ":encoding(cp932)";

$FLAC = "flac";
$LAME = "/cygdrive/c/usr/soft/lame/lame.exe";

$debug = 1;
$verbose = 1;

#&id3write("33.mp3");
#exit(0);

for ($i = 0; $i <= $#ARGV; $i++) {
    $cue = $ARGV[$i];
    &flac2mp3($cue);
}


sub flac2mp3 {
    my ($cue) = @_;	# CUE シートファイル名

    my $flac;		# FLAC ファイル名
    my $track = 0;	# トラック数
    my $title;		# アルバムタイトル
    my $performer;	# アルバムパフォーマー
    my @track_num;	# トラック番号
    my @track_type;	# トラック形式 (AUDIO)
    my @track_title;	# トラックタイトル
    my @track_performer;	# トラックパフォーマー
    my @track_head;	# トラック先頭位置

    my $line;
    my $i;

    print "Cue Sheet: $cue\n";
    open(IN, $cue) || die "Can't open <$cue>\n";
    while ($line = <IN>) {
	$line = decode(cp932 => $line);  # CUEシートはShift JISを想定
	if ($line =~ /FILE\s+"(.*)"\s+(\s*)/) {
	    $flac = $1;
	    print "FLAC File: $flac\n" if $debug;
	}
	elsif ($line =~ /PERFORMER\s+"(.*)"/) {
	    if ($track == 0) {
		$performer = $1;
		print "Performer: $performer\n" if $debug;
	    }
	    else {
		$track_performer[$track] = $1;
	    }
	}
	elsif ($line =~ /TITLE\s+"(.*)"/) {
	    if ($track == 0) {
		$title = $1;
		print "Title: $title\n" if $debug;
	    }
	    else {
		$track_title[$track] = $1;
		print "Title: $track_title[$track]\n" if $debug;
	    }
	}
	elsif ($line =~ /TRACK\s+([0-9]+)\s+(\S+)/) {
	    $track++;
	    $track_num[$track] = $1;
	    $track_type[$track] = $2;
	    if ($debug) {
		print "Track: $track\n";
		print "  Num: $track_num[$track]\n";
		print " Type: $track_type[$track]\n";
	    }
	}
	elsif ($line =~ /INDEX\s+([0-9]+)\s+([0-9:]+)/) {
	    if ($track > 0) {
		if ($1 == 1) {
		    $track_head[$track] = $2;
		}
	    }
	}
    }
    close(IN);
    
    for ($i = 1; $i <= $track; $i++) {
#    for ($i = 1; $i <= 1; $i++) { # for debug
#    for ($i = 33; $i <= 33; $i++) { # for debug
	#$pn = 11; for ($i = $pn; $i <= $pn; $i++) {
	if ($verbose) {
	    print "Track: $i\n";
	    print "  Num       : $track_num[$i]\n";
	    print "  Type      : $track_type[$i]\n";
	    print "  Title     : $track_title[$i]\n";
	    print "  Performer : $track_performer[$i]\n";
	    print "  Head      : $track_head[$i]\n";
	}
	
	#my $wav = "flac2mp3_$i.wav";
	my $wav = "flac2mp3.wav";
	my $mp3;
	my $skip;
	my $until;
	
	$mp3 = sprintf("%02d_%s.mp3", $track_num[$i], &fname($track_title[$i]));
	
	$skip = "--skip=" . &mmss($track_head[$i]);
	if ($i < $track) {
	    $until = "--until=" . &mmss($track_head[$i+1]);
	}
	else {
	    $until = "";
	}
	unlink($wav);
	$cmd = "flac --force --decode --output-name=\"$wav\" $skip $until \"$flac\"";
	print "CMD: $cmd\n";
	system($cmd);

	@cmd = (
	    "$LAME",
	    "--cbr",
	    "-b", "128",
	    "--id3v1-only",
	    "--tt", encode(cp932 => $track_title[$i]),
#	    "--tt", $track_title[$i],
	    "--ta", encode(cp932 => $performer),
	    "--tl", encode(cp932 => $title),
	    "--tn", $track_num[$i],
	    $wav, $mp3
	    );
	print "CMD: @cmd\n";
	system(@cmd);

	&id3write($mp3, $title, $track_title[$i], $performer);

    } # for track    
}

#
# ID3v1 タグに情報を書き込む
#

sub id3write {
    my ($mp3, $album, $track, $artist) = @_;
    my $buf, @b;

    my $j_album  = &str_jis_fit($album, 30);
    my $j_track  = &str_jis_fit($track, 30);
    my $j_artist = &str_jis_fit($artist, 30);

    #print decode(cp932 => &str_sjis_fit("A０１２３４５６７８９０１２３４５６７８９", 30)), "\n";

    open(IN, "+<$mp3") || die "Can't open <$mp3>";
    binmode(IN);

    # read ID3v1 tag
    seek(IN, -128, 2) || die "Can't seek";
    read(IN, $buf, 128); # ID3v1 タグは 末尾128バイト
#   print $buf, "\n";

    @b = unpack("C*", $buf);
    if (chr($b[0]) == 'T' && chr($b[1]) == 'A' && chr($b[2]) == 'G') {
	print "ID3v1 found\n";
	&subst(@b,  3, 30, $j_track);
	&subst(@b, 33, 30, $j_artist);
	&subst(@b, 63, 30, $j_album);

	# write ID3v1 tag
	seek(IN, -128, 2) || die "Can't seek";
        $buf = pack("C*", @b);
	print $buf;
	write(IN, $buf, 128);
    }
    else {
	print "ID3v1 tag not found\n";
    }

    close(IN);
}

sub str_jis_fit {
    my ($str, $len) = @_;
    use bytes();
    my $jstr;
    while (1) {
#	print encode(utf8 => $str), "\n";
	$jstr = encode('iso-2022-jp' => $str);
	if (bytes::length($jstr) <= $len) {
	    last;
	}
	chop($str);
    }
    $jstr;
}

sub subst {
    my (@b, $start, $len, $str) = @_;
    my $i;
    my $slen = bytes::length($str);
    my $l = ($len < $slen) ? $len : $slen;
    for ($i = 0, $i < $l, $i++) {
	$b[$start + $i] = ord(bytes::substr($str, $i, 1));
    }
    for (; $i < $len; $i++) {
	$b[$start + $i] = 0;
    }
}

#
#	時刻フォーマット変換 MM:SS:DD => MM:SS.ss
#

sub mmss {
    my ($mmssaa) = @_;
    my $m, $s, $a;
    my $mm, $ss;
    if ($mmssaa =~ /^(\d+):(\d+):(\d+)$/) {
	$m = $1;
	$s = $2;
	$a = $3;
    }
    else {
	die "mmss: format error: <$hhmmss>\n";
    }
    
    $mm = $m;
    $ss = $s . sprintf(".%02d", int($a*100/60));
    return "$mm:$ss";
}

sub fname {
    my ($str) = @_;
    $str =~ s/\//／/g; # 2byte
    $str =~ s/\?/？/g;
    $str;
}


