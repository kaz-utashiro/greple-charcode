package App::Greple::annotate;

use 5.024;
use warnings;
use utf8;

our $VERSION = "0.9902";

=encoding utf-8

=head1 NAME

App::Greple::annotate - greple module for generic annotation

=head1 SYNOPSIS

B<greple> B<-Mannotate> ...

=head1 VERSION

Version 0.9902

=head1 DESCRIPTION

C<App::Greple::annotate> module is made for C<App::Greple::charcode>
to display annotation for each matched text in the following style.

    $ greple -Mcharcode '\P{ASCII}' charcode.pm

            ┌───  12 \x{fe0e} \N{VARIATION SELECTOR-15}
            │ ┌─  14 \x{a9} \N{COPYRIGHT SIGN}
            │ ├─  14 \x{fe0e} \N{VARIATION SELECTOR-15}
    Copyright︎ ©︎ 2025 Kazumasa Utashiro.

=for html <p>
<img width="750" src="https://raw.githubusercontent.com/kaz-utashiro/greple-charcode/refs/heads/main/images/ka-ko.png">
</p>

=head1 COMMAND OPTIONS

=over 7

=item B<--annotate>, B<--no-annotate>

Print annotation or not.  Enabled by default, so use C<--no-annotate>
to disable it.

=back

=head1 MODULE OPTIONS

=over 7

=item B<--align>=I<column>

Align annotation messages.  Defaults to C<1>, which aligns to the
rightmost column; C<0> means no align; if a value of C<2> or greater
is given, it aligns to that numbered column.

I<column> can be negative; if C<-1> is specified, align to the same
column for all lines.  If C<-2> is specified, align to the longest
line length, regardless of match position.

=item B<--split>, B<--no-split>

If a pattern matching multiple characters is given, annotate each
character independently.

=back

=head1 VARIABLES

=over 7

=item B<$App::Greple::annotate::ANNOTATE>

Hold function reference to produce annotation text.  Default function
is declared as this:

    our $ANNOTATE //= sub {
        my %param = @_;
        my($column, $str) = @param{qw(column match)};
        sprintf("%3d %s", $column, $str);
    };

Parameter is passed by C<column> and C<match> labeled list.

=back

=head1 CONFIGURATION

Configuration parameters can be set in several ways.

=head2 MODULE START FUNCTION

The start function of a module can be specified at the same time as
the module declaration.

    greple -Mannotate::config(align=0)

    greple -Mannotate::config=align=80

=head2 PRIVATE MODULE OPTION

Module-specific options are specified between C<-Mannotate> and C<-->.

    greple -Mannotate --config align=80 -- ...

    greple -Mannotate --align=80 -- ...

=head1 CONFIGURATION PARAMETERS

=over 7

=item B<align>

(default 1) Align the description on the rightmost column, or numbered
column if the value is greater than 2.

=back

=head1 INSTALL

cpanm -n B<App::Greple::annotate>

=head1 SEE ALSO

L<App::Greple>

L<App::Greple::charcode>

=head1 LICENSE

Copyright︎ ©︎ 2025 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Kazumasa Utashiro

=cut

use Getopt::EX::Config;
use Hash::Util qw(lock_keys);
use Data::Dumper;

our $config = Getopt::EX::Config->new(
    annotate => \(our $opt_annotate = 1),
    align => 1,
    split => 0,
);
my %type = ( align => '=i', '*' => '!' );
lock_keys %{$config};

sub finalize {
    our($mod, $argv) = @_;
    $config->deal_with(
	$argv,
	(
	    map {
		my $type = $type{$_} // $type{'*'};
		( $_.$type => ref $config->{$_} ? $config->{$_} : \$config->{$_} ) ;
	    }
	    keys %{$config}
	),
    );
}

use Text::ANSI::Fold::Util qw(ansi_width);
Text::ANSI::Fold->configure(expand => 1);
*vwidth = \&ansi_width;

package Local::Annon {
    sub new {
	my $class = shift;
	@_ == 3 or die;
	bless [ @_ ], $class;
    }
    sub start         { shift->[0] }
    sub end           { shift->[1] }
    sub annon :lvalue { shift->[2] }
}

package Local::Annon::List {
    use strict;
    use warnings;
    use List::Util;
    sub new {
	my $class = shift;
	bless {
	    Annotation => [],
	    Count      => [],
	}, $class;
    }
    sub annotation { $_[0]->{Annotation} }
    sub count { $_[0]->{Count} }
    sub push {
	my $obj = CORE::shift;
	push @{$obj->annotation}, @_;
	push @{$obj->count}, int @_;
    }
    sub append {
	my $obj = CORE::shift;
	CORE::push @{$obj->annotation}, @_;
	$obj->count->[-1] += int @_;
    }
    sub shift {
	my $obj = CORE::shift;
	my $count = CORE::shift @{$obj->count} or return ();
	splice @{$obj->annotation}, 0, $count;
    }
    sub join {
	my $obj = CORE::shift;
	for (@_) {
	    CORE::push @{$obj->annotation}, @{$_->annotation};
	    CORE::push @{$obj->count}, @{$_->count};
	}
    }
    sub total {
	my $obj = CORE::shift;
        List::Util::sum(@{$obj->count}) // 0;
    }
    sub last {
	my $obj = CORE::shift;
        $obj->annotation->[-1];
    }
    sub maxpos {
	my $obj = CORE::shift;
        List::Util::max map { $_->end } @{$obj->annotation};
    }
}

sub code {
    state $format = [ qw(\x{%02x} \x{%04x}) ];
    my $ord = ord($_[0]);
    sprintf($format->[$ord > 0xff], $ord);
}

my %cmap = (
    "\t" => '\t',
    "\n" => '\n',
    "\r" => '\r',
    "\f" => '\f',
    "\b" => '\b',
    "\a" => '\a',
    "\e" => '\e',
);

sub control {
    local $_ = @_ ? shift : $_;
    if (s/\A([\t\n\r\f\b\a\e])/$cmap{$1}/e) {
	$_;
    } elsif (s/\A([\x00-\x1f])/sprintf "\\c%c", ord($1)+0x40/e) {
	$_;
    } else {
	code($_);
    }
}

sub visible {
    local $_ = @_ ? shift : $_;
    s{([^\pL\pN\pP\pS])}{control($1)}ger;
}

my $annotation = Local::Annon::List->new;

our $ANNOTATE //= sub {
    my %param = @_;
    my($column, $str) = @param{qw(column match)};
    sprintf("%3d %s", $column, visible($str));
};

sub prepare {
    config('annotate') or return;
    my $grep = shift;
    for my $r ($grep->result) {
	my($b, @match) = @$r;
	my @slice = $grep->slice_result($r);
	my $start = 0;
	my $progress = '';
	my $indent = '';
	my $current = Local::Annon::List->new;
	while (my($i, $slice) = each @slice) {
	    next if $slice eq '';
	    my $end = vwidth($progress . $slice);
	    my $gap = $end - $start;
	    my $indent_mark = '';
	    if ($i % 2) {
		my $match = $match[$i / 2];
		$indent_mark = '│';
		my $head = '┌';
		if ($gap == 0) {
		    if ($start == 0) {
			$head = '╾';
			$indent_mark = '';
		    } elsif ($current->total > 0 and $current->last->end == $start) {
			$head = '├';
			$start = $current->last->start;
			substr($indent, $start) = '';
		    } elsif ($start > 0) {
			$start = vwidth($progress =~ s/\X\z//r);
			substr($indent, $start) = '';
		    }
		}
		$current->push( do {
		    my $maker = sub {
			my($head, $match) = @_;
			sprintf("%s%s─ %s", $indent, $head,
				$ANNOTATE->(column => $start, match => $match));
		    };
		    if ($config->{split}) {
			map {
			    my $out = $maker->($head, $_);
			    $head = '├';
			    Local::Annon->new($start, $end, $out);
			}
			$slice =~ /./sg;
		    } else {
			Local::Annon->new($start, $end, $maker->($head, $slice));
		    }
		} );
	    }
	    $indent .= sprintf("%-*s", $end - $start, $indent_mark);
	    $progress .= $slice;
	    $start = $end;
	}
	@{$current->count} == 0 and next;
	my $align = $config->{align};
	if ($align > 0 and $current->total > 0) {
	    align($current,
		  $align > 1 ? $align : $current->last->[0]);
	}
	$annotation->join($current);
    }
    if ($config->{align} == -1) {
	align($annotation, $annotation->maxpos);
    }
    elsif ($config->{align} == -2) {
	my $maxlen = List::Util::max(
	    map { vwidth($grep->cut($_->[0]->@*)) } $grep->result
	);
	align($annotation, $maxlen - 1);
    }
}

sub align {
    my($list, $pos) = @_;
    for (@{$list->annotation}) {
	if ((my $extend = $pos - $_->[0]) > 0) {
	    $_->annon =~ s/(?=([─]))/$1 x $extend/e;
	}
    }
}

sub annotate {
    config('annotate') or return;
    if (my @annon = $annotation->shift) {
	say $_->annon for @annon;
    }
    undef;
}

1;

__DATA__

builtin annotate! $opt_annotate

option default \
    --postgrep '&__PACKAGE__::prepare' \
    --callback '&__PACKAGE__::annotate'

option --annotate::config \
    --prologue &__PACKAGE__::config($<shift>)

option --config --annotate::config
