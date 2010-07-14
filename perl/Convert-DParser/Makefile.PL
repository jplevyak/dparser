#
use ExtUtils::MakeMaker;

WriteMakefile
  (
   NAME         => 'Convert-DParser'
   , VERSION => '0.0'
   , 'ABSTRACT'	=> 'a 3GPP ASN1,CSN,EBNF, TTCN2-3, converter using the Da Parser (Tomota)'
   , 'AUTHOR'	=> 'Christian Montanari <christian.montanari@sharp.eu>'
   , 'PREREQ_PM' => {
       'IO::String'		=> 0
	   , 'IO::File'		=> 0
	   , 'Data::Dumper'	=> 2.121
	   , 'Data::Hexdumper'	=> 1.2
	   , 'File::Temp'   	=> 0.16
	   , File::Spec		=> 0
	   , File::Path		=> 0
	   , 'Test::More'      	=> 0.34
	   , 'Test::Exception'	=> 0
	   , 'Class::Container'	=> 0.12
	   , 'Params::Validate'	=> 0
	   , Graphviz		=> 0
	   , Parser::D		=> 1.14
   }
   , FIRST_MAKEFILE => 'Makefile.perl'
   , LICENSE	=> 'perl'
  );
