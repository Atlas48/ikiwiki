#!/usr/bin/perl
# Table Of Contents generator
package IkiWiki::Plugin::toc;

use warnings;
use strict;
use IkiWiki;
use HTML::Parser;

sub import { #{{{
	IkiWiki::hook(type => "preprocess", id => "toc",
		call => \&preprocess);
	IkiWiki::hook(type => "format", id => "toc",
		call => \&format);
} # }}}

my %tocpages;

sub preprocess (@) { #{{{
	my %params=@_;

	$params{levels}=1 unless exists $params{levels};

	# It's too early to generate the toc here, so just record the
	# info.
	$tocpages{$params{destpage}}=\%params;

	return "\n<div class=\"toc\"></div>\n";
} # }}}

sub format (@) { #{{{
	my %params=@_;
	my $content=$params{content};
	
	return $content unless exists $tocpages{$params{page}};
	%params=%{$tocpages{$params{page}}};

	my $p=HTML::Parser->new(api_version => 3);
	my $page="";
	my $index="";
	my %anchors;
	my $curlevel;
	my $startlevel=0;
	my $liststarted=0;
	my $indent=sub { "\t" x $curlevel };
	$p->handler(start => sub {
		my $tagname=shift;
		my $text=shift;
		if ($tagname =~ /^h(\d+)$/i) {
			my $level=$1;
			my $anchor="index".++$anchors{$level}."h$level";
			$page.="$text<a name=\"$anchor\" />";
	
			# Take the first header level seen as the topmost level,
			# even if there are higher levels seen later on.
			if (! $startlevel) {
				$startlevel=$level;
				$curlevel=$startlevel-1;
			}
			elsif ($level < $startlevel) {
				$level=$startlevel;
			}
			
			return if $level - $startlevel >= $params{levels};
	
			if ($level > $curlevel) {
				while ($level > $curlevel + 1) {
					$index.=&$indent."<ol>\n";
					$curlevel++;
					$index.=&$indent."<li class=\"L$curlevel\">\n";
				}
				$index.=&$indent."<ol>\n";
				$curlevel=$level;
				$liststarted=1;
			}
			elsif ($level < $curlevel) {
				while ($level < $curlevel) {
					$index.=&$indent."</li>\n" if $curlevel;
					$curlevel--;
					$index.=&$indent."</ol>\n";
				}
				$liststarted=0;
			}
	
			$p->handler(text => sub {
				$page.=join("", @_);
				$index.=&$indent."</li>\n" unless $liststarted;
				$liststarted=0;
				$index.=&$indent."<li class=\"L$curlevel\">".
					"<a href=\"#$anchor\">".
					join("", @_).
					"</a>\n";
				$p->handler(text => undef);
			}, "dtext");
		}
		else {
			$page.=$text;
		}
	}, "tagname, text");
	$p->handler(default => sub { $page.=join("", @_) }, "text");
	$p->parse($content);
	$p->eof;

	while ($startlevel && $curlevel >= $startlevel) {
		$index.=&$indent."</li>\n" if $curlevel;
		$curlevel--;
		$index.=&$indent."</ol>\n";
	}

	$page=~s/(<div class=\"toc\">)/$1\n$index/;
	return $page;
}

1
