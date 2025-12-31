requires 'perl', '5.024';

requires 'App::Greple', '9.2101';
requires 'App::ansicolumn';
requires 'Getopt::EX::Config', '1.0201';
requires 'Text::ANSI::Fold', '2.29';
requires 'Text::ANSI::Fold::Util';
requires 'Text::VisualWidth::PP', '0.08';
requires 'Hash::Util';
requires 'Unicode::UCD';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

