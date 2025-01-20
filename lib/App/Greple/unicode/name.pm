package App::Greple::unicode::name;

use 5.014;
use warnings;
use utf8;

our $VERSION = "0.01";

=encoding utf-8

=head1 NAME

App::Greple::unicode::name - greple -Municode::name module

=head1 SYNOPSIS

    greple -Muncode::name

=head1 VERSION

Version 0.01

=head1 DESCRIPTION

App::Greple::unicode::name is ...

=head1 LICENSE

Copyright︎ ©︎ 2025 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Kazumasa Utashiro

=cut

use Data::Dumper;
use Getopt::EX::Config qw(config);

my $config = Getopt::EX::Config->new(
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
    push @s, "{$_}"                           if $config->{char};
    push @s, sprintf("\\w{%d}", vwidth($_))   if $config->{width};
    push @s, join '', map { charcode } /./g if $config->{code};
    push @s, join '', map { charname } /./g if $config->{name};
    join "\N{NBSP}", @s;
}

sub prepare {
    our @annotation;
    my $grep = shift;
    for my $r ($grep->result) {
	my @annon;
	my($b, @match) = @$r;
	my @slice = $grep->slice_result($r);
	my $pos = 0;
	my $lead = '';
	while (my($i, $s) = each @slice) {
	    my $out = '';
	    my $w = vwidth($s);
	    if ($i % 2) {
		my $desc = describe($slice[$i]);
		if (@annon == 0 or $annon[-1]->[0] ne $pos) {
		    $out = sprintf "%s┌─ %s\n", $lead, $desc;
		    $lead .= '│';
		    $lead .= ' ' x ($w - 1) if $w > 1;
		} else {
		    $out = sprintf "%s├─ %s\n", substr($lead, 0, -1), $desc;
		}
		push @annon, [ $pos, $out ];
	    } else {
		$lead .= ' ' x $w if $w > 0;
	    }
	    $pos += $w;
	}
	if ($config->{align} and @annon and (my $max_indent = $annon[-1]->[0])) {
	    for (@annon) {
		if ((my $room = $max_indent - $_->[0]) > 0) {
		    $_->[1] =~ s/(?=([─]))/$1 x $room/e;
		}
	    }
	}
	push @annotation, map { $_->[1] } @annon;
    }
}

sub annotate {
    our @annotation;
    print shift(@annotation) if @annotation > 0;
    undef;
}

1;

__DATA__

option default --separate --annotate

option --annotate \
    --postgrep &__PACKAGE__::prepare \
    --callback &__PACKAGE__::annotate
