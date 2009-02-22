
use Module::Build;

my $build = new Module::Build(
	module_name => 'SQL::Beautify',
	license     => 'artistic_2',
	requires    => {
		'perl'           => '5.8.5',
		'Carp'           => '0',
		'SQL::Tokenizer' => '0.18',
	},
);

$build->create_build_script;
