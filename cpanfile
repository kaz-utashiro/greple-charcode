requires 'perl', '5.014';

requires 'App::Greple', '9.18';
requires 'Unicode::UCD';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

