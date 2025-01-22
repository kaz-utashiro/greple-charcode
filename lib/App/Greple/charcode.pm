package App::Greple::charcode;

use 5.014;
use warnings;
use utf8;

our $VERSION = "0.01";

=encoding utf-8

=head1 NAME

App::Greple::charcode - greple -Mcharcode module

=head1 SYNOPSIS

    greple -Mcharcode

=head1 VERSION

Version 0.01

=head1 DESCRIPTION

App::Greple::charcode is ...

=head1 LICENSE

Copyright︎ ©︎ 2025 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Kazumasa Utashiro

=cut

use Getopt::EX::Config qw(config);

my $config = Getopt::EX::Config->new(
    col   => 1,
    char  => 0,
    width => 0,
    code  => 1,
    name  => 1,
    align => 1,
);

sub finalize {
    our($mod, $argv) = @_;
    $config->deal_with($argv);
}

use Text::ANSI::Fold::Util qw(ansi_width);
Text::ANSI::Fold->configure(expand => 1);
*vwidth = \&ansi_width;
use Unicode::UCD qw(charinfo);
use Data::Dumper;

sub charname {
    local $_ = @_ ? shift : $_;
    s/(.)/name($1)/ger;
}

sub name {
    my $char = shift;
    "\\N{" . Unicode::UCD::charinfo(ord($char))->{name} . "}";
}

sub charcode {
    local $_ = @_ ? shift : $_;
    state $format = [ qw(\x{%02x} \x{%04x}) ];
    my $start = $config->{newline} ? "\n" : "";
    my $end   = $config->{newline} ? "\n" : "";
    s/(.)/code($1)/ger;
}

sub code {
    state $format = [ qw(\x{%02x} \x{%04x}) ];
    my $ord = ord($_[0]);
    sprintf($format->[$ord > 0xff], $ord);
}

sub describe {
    local $_ = shift;
    my @s;
    push @s, "{$_}"                         if $config->{char};
    push @s, sprintf("\\w{%d}", vwidth($_)) if $config->{width};
    push @s, join '', map { charcode } /./g if $config->{code};
    push @s, join '', map { charname } /./g if $config->{name};
    join "\N{NBSP}", @s;
}

package #
Annon {
    sub new {
	my $class = shift;
	@_ == 3 or die;
	bless [ @_ ], $class;
    }
    sub start :lvalue { shift->[0] }
    sub end   :lvalue { shift->[1] }
    sub annon :lvalue { shift->[2] }
}

sub prepare {
    our @annotation;
    my $grep = shift;
    for my $r ($grep->result) {
	my($b, @match) = @$r;
	my @slice = $grep->slice_result($r);
	my $start = 0;
	my $progress = '';
	my $indent = '';
	my @annon;
	while (my($i, $slice) = each @slice) {
	    my $end = $slice eq '' ? $start : vwidth($progress . $slice);
	    my $gap = $end - $start;
	    my $indent_mark = '';
	    if ($i % 2) {
		$indent_mark = '│';
		my $mark = '┌';
		if ($gap == 0) {
		    if (@annon > 0 and $annon[-1]->end == $start) {
			$mark = '├';
			$start = $annon[-1]->start;
			substr($indent, $start) = '';
		    } elsif ($start > 0) {
			$start = vwidth($progress =~ s/\X\z//r);
			substr($indent, $start) = '';
		    }
		}
		my $column = $config->{col} ? sprintf("%3d ", $start) : '';
		my $out = sprintf("%s%s─ %s%s",
				  $indent,
				  $mark,
				  $column,
				  describe($slice));
		push @annon, Annon->new($start, $end, $out);
	    }
	    $indent .= sprintf("%-*s", $end - $start, $indent_mark);
	    $progress .= $slice;
	    $start = $end;
	}
	@annon or next;
	if ($config->{align} and (my $max_pos = $annon[-1][0])) {
	    for (@annon) {
		if ((my $extend = $max_pos - $_->[0]) > 0) {
		    $_->annon =~ s/(?=([─]))/$1 x $extend/e;
		}
	    }
	}
	push @annotation, map $_->annon, @annon;
    }
}

sub _lastchar {
    ( $_[0] =~ /(\X)$/ )[0];
}

sub annotate {
    our @annotation;
    say shift(@annotation) if @annotation > 0;
    undef;
}

1;

__DATA__

option default --separate --annotate --uniqcolor

option --annotate \
    --postgrep &__PACKAGE__::prepare \
    --callback &__PACKAGE__::annotate
