#
use ExtUtils::MakeMaker;

WriteMakefile
  (
   NAME         => 'Convert-DParser'
   , VERSION => '0.0'
   , 'ABSTRACT'	=> 'contains an interpreter using the Da Parser (Tomota). a base for to some ASN1,CSN,EBNF,TTCN2-3 grammar described in simple EBNF'
   , 'AUTHOR'	=> 'Christian Montanari <christian.montanari@sharp.eu>'
   , 'PREREQ_PM' => {
       'IO::String'		=> 0
	   , 'IO::File'		=> 0
	   , 'Data::Dumper'	=> 2.121
	   , 'Data::Hexdumper'	=> 1.2
	   , File::Temp   	=> 0.16
	   , File::Spec		=> 3.31
	   , File::Path		=> 2.08
	   , File::Basename	=> 5.12
	   , 'Test::More'      	=> 0.34
	   , 'Test::Exception'	=> 0
	   , Class::Container	=> 0.12
	   , Params::Validate	=> 0.95
	   , Graphviz		=> 2.04
	   , Parser::D		=> 1.14
	   , Convert::ASN1	=> 0.22
   }
   , FIRST_MAKEFILE => 'Makefile.perl'
   , LICENSE	=> 'perl'
   , clean => { FILES => 'asn_*.i .d_parser.*.o .*.c *.*.fig' }
  );
