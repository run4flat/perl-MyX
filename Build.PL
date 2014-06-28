use Module::Build;
Module::Build->new(
	dist_name => 'MyX',
	license  => 'perl',
	requires => {
		'Filter::Simple'  => 0,
	},
	dist_author => 'David Mertens <dcmertens.perl@gmail.com>',
	dist_version => 0.01,
)->create_build_script;