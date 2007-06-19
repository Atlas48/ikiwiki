#!/usr/bin/perl
# Ikiwiki enhanced image handling plugin
# Christian Mock cm@tahina.priv.at 20061002
package IkiWiki::Plugin::img;

use warnings;
use strict;
use IkiWiki 2.00;

my %imgdefaults;

sub import { #{{{
	hook(type => "preprocess", id => "img", call => \&preprocess, scan => 1);
} #}}}

sub preprocess (@) { #{{{
	my ($image) = $_[0] =~ /$config{wiki_file_regexp}/; # untaint
	my %params=@_;

	if (! exists $imgdefaults{$params{page}}) {
		$imgdefaults{$params{page}} = {};
	}
	my $size = $params{size} || $imgdefaults{$params{page}}->{size} || 'full';
	my $alt = $params{alt} || $imgdefaults{$params{page}}->{alt} || '';

	if ($image eq 'defaults') {
		$imgdefaults{$params{page}} = {
			size => $size,
			alt => $alt,
		};
		return '';
	}

	push @{$links{$params{page}}}, $image;
	my $file = bestlink($params{page}, $image);

	my $dir = $params{page};
	my $base = IkiWiki::basename($file);

	eval q{use Image::Magick};
	error($@) if $@;
	my $im = Image::Magick->new;
	my $imglink;
	my $r;

	if ($size ne 'full') {
		my ($w, $h) = ($size =~ /^(\d+)x(\d+)$/);
		return "[[img ".sprintf(gettext('bad size "%s"'), $size)."]]"
			unless (defined $w && defined $h);

		my $outfile = "$config{destdir}/$dir/${w}x${h}-$base";
		$imglink = "$dir/${w}x${h}-$base";
		
		will_render($params{page}, $imglink);

		if (-e $outfile && (-M srcfile($file) >= -M $outfile)) {
			$r = $im->Read($outfile);
			return "[[img ".sprintf(gettext("failed to read %s: %s"), $outfile, $r)."]]" if $r;
		}
		else {
			$r = $im->Read(srcfile($file));
			return "[[img ".sprintf(gettext("failed to read %s: %s"), $file, $r)."]]" if $r;

			$r = $im->Resize(geometry => "${w}x${h}");
			return "[[img ".sprintf(gettext("failed to resize: %s"), $r)."]]" if $r;

			# don't actually write file in preview mode
			if (! $params{preview}) {
				my @blob = $im->ImageToBlob();
				writefile($imglink, $config{destdir}, $blob[0], 1);
			}
			else {
				$imglink = $file;
			}
		}
	}
	else {
		$r = $im->Read(srcfile($file));
		return "[[img ".sprintf(gettext("failed to read %s: %s"), $file, $r)."]]" if $r;
		$imglink = $file;
	}

	add_depends($imglink, $params{page});

	my ($fileurl, $imgurl);
	if (! $params{preview}) {
		$fileurl=urlto($file, $params{destpage});
		$imgurl=urlto($imglink, $params{destpage});
	}
	else {
		$fileurl="$config{url}/$file";
		$imgurl="$config{url}/$imglink";
	}

	if (! defined($im->Get("width")) || ! defined($im->Get("height"))) {
		return "[[img ".sprintf(gettext("failed to determine size of image %s"), $file)."]]";
	}

	return '<a href="'.$fileurl.'"><img src="'.$imgurl.
		'" alt="'.$alt.'" width="'.$im->Get("width").
		'" height="'.$im->Get("height").'"'.
		(exists $params{class} ? ' class="'.$params{class}.'"' : '').
		(exists $params{id} ? ' id="'.$params{id}.'"' : '').
		' /></a>';
} #}}}

1
