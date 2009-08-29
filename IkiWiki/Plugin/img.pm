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

	if (exists $imgdefaults{$params{page}}) {
		foreach my $key (keys %{$imgdefaults{$params{page}}}) {
			if (! exists $params{$key}) {
				$params{$key}=$imgdefaults{$params{page}}->{$key};
			}
		}
	}

	if (! exists $params{size}) {
		$params{size}='full';
	}

	if ($image eq 'defaults') {
		$imgdefaults{$params{page}} = \%params;
		return '';
	}

	push @{$links{$params{page}}}, $image;
	# optimisation: detect scan mode, and avoid generating the image
	if (! defined wantarray) {
		return;
	}

	my $file = bestlink($params{page}, $image);

	my $dir = $params{page};
	my $base = IkiWiki::basename($file);

	eval q{use Image::Magick};
	error($@) if $@;
	my $im = Image::Magick->new;
	my $imglink;
	my $r;

	my ($dwidth, $dheight);

	if ($params{size} ne 'full') {
		my ($w, $h) = ($params{size} =~ /^(\d+)x(\d+)$/);
		return "[[img ".sprintf(gettext('bad size "%s"'), $params{size})."]]"
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

			# don't resize any larger
			my ($rw, $rh) = ($w, $h);
			if ($rw > $im->Get("width") ||
			    $rh > $im->Get("height")) {
				$rw=$im->Get("width");
				$rh=$im->Get("height");
			}

			$r = $im->Resize(geometry => "${rw}x${rh}");
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

		# since we don't really resize larger, set the display
		# size, so the browser can scale the image up if necessary
		($dwidth, $dheight)=($w, $h);
	}
	else {
		$r = $im->Read(srcfile($file));
		return "[[img ".sprintf(gettext("failed to read %s: %s"), $file, $r)."]]" if $r;
		$imglink = $file;
		$dwidth = $im->Get("width");
		$dheight = $im->Get("height");
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

	my $imgtag='<img src="'.$imgurl.
		'" alt="'.(exists $params{alt} ? $params{alt} : '').
		'" width="'.$dwidth.
		'" height="'.$dheight.'"'.
		(exists $params{title} ? ' title="'.$params{title}.'"' : '').
		(exists $params{class} ? ' class="'.$params{class}.'"' : '').
		(exists $params{id} ? ' id="'.$params{id}.'"' : '').
		' />';

	if (! defined $params{link} || lc($params{link}) eq 'yes') {
		$imgtag='<a href="'.$fileurl.'">'.$imgtag.'</a>';
	}
	elsif ($params{link} =~ /^\w+:\/\//) {
		$imgtag='<a href="'.$params{link}.'">'.$imgtag.'</a>';
	}
	elsif (length bestlink($params{page}, $params{link})) {
		add_depends($params{page}, $params{link});
		$imgtag=htmllink($params{page}, $params{destpage},
			$params{link}, linktext => $imgtag,
			noimageinline => 1);
	}

	if (exists $params{caption}) {
		return '<table class="img">'.
			'<caption>'.$params{caption}.'</caption>'.
			'<tr><td>'.$imgtag.'</td></tr>'.
			'</table>';
	}
	else {
		return $imgtag;
	}
} #}}}

1
