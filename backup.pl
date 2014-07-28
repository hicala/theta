#!/usr/bin/perl
use XML::Simple;
use Data::Dumper;

# **************************************************************************
# CONFIG
# $path = Unix path where the data.xml is located.-
# $SIZE = max file system usage before cleaning it up.-
# **************************************************************************
my $path	= '/opt/PerlBackup';
our $SIZE	= 70;

# **************************************************************************
# XML
# Load data.xml into memory.-
# **************************************************************************
my $xml 	= new XML::Simple;
my $data 	= $xml->XMLin("$path/data.xml");
my %table;
our $ts 	= `date +%s`; chomp $ts;

# **************************************************************************
# HANDLERS
# Determine which handlers are available for the system. Handlers 
# include local file systems, NFSs, external hard-drives, etc
# **************************************************************************
print "\n Handlers: \n";
my @k = keys %{$data->{handler}};
my $i = 0;
while ( defined $k[$i] ) {
	my $key = $k[$i];
	if ($key) {
		# Determine table.-
		$table{handler}{$key} 			= {};
		$table{handler}{$key}{name} 		= $key;
		$data->{handler}{$key}{location} 	=~ s/\/$//;
		$table{handler}{$key}{location}		= $data->{handler}{$key}{location};
		$table{handler}{$key}{destination}	= $data->{handler}{$key}{location}."/backup-$ts/";
		$table{handler}{$key}{type} 		= $data->{handler}{$key}{type};
		$table{handler}{$key}{available} 	= 0;
		if ( $table{handler}{$key}{type} =~ /mount|local/i ) {
			$out = `ls -d $table{handler}{$key}{location} 2> /dev/null`;
			if ( $out ) {
				$table{handler}{$key}{available} = 1;
			}
		}
		# Print summary.-
		$table{handler}{$key}{available} and $status = "Available" or $status = "OFF";
		printf " %-10s %s %-10s %-30s \n", $key, $table{handler}{$key}{type}, $status, $table{handler}{$key}{destination};
	}
	$i++;
}
print "\n";

# **************************************************************************
# SOURCE
# This checks which files are to be backed up. Compressing can be
# configured at the data.xml
# **************************************************************************
print " Source: \n";
my $i = 0;
while ( defined $data->{source}[$i] ) {
	my %s;
	
	# Should I compress?
	if ( $data->{source}[$i]{compress} eq "true" ) { $s{compress} = 1 } 
	else { $s{compress} = 0; }

	# Check handlers.-
	my $h = 0;
	my @handler; 
	while ( defined	$data->{source}[$i]{handler}[$h] ) {
		my $hn = $data->{source}[$i]{handler}[$h];
		my $kk = $table{handler}{$hn}{available};
		if ($hn and $kk) { push @handler, $hn; }
		$h++;
	}
	if ( defined $handler[0] ) { $s{handler} = \@handler; }
	elsif ( defined $data->{source}[$i]{handler} ) { 
			my $hn = $data->{source}[$i]{handler};
			my $kk = $table{handler}{$hn}{available};
			if ( $hn and $kk ) { $s{handler} = [ $data->{source}[$i]{handler} ]; }
	}

	# List files.-
	my $h = 0;
	my @files; 
	while ( defined	$data->{source}[$i]{dir}[$h] ) {
		my $hn = $data->{source}[$i]{dir}[$h];
		if ($hn) { push @files, $hn; }
		$h++;
	}
	if ( defined $files[0] ) { $s{dir} = \@files; $s{total} = $h; }
	elsif ( defined $data->{source}[$i]{dir} ) { $s{dir} = [ $data->{source}[$i]{dir} ]; $s{total}=1;}

	# Add to list and print summary.-!
	if ($s{handler}) {
		push @{$table{source}}, \%s;
		$s{compress} and $c = "TAR!" or $c = "";
		printf " %-2d Files %-4s Handler=%-20s %-3s \n", $s{total}, $c, join(',',@{$s{handler}});
	}
	$i++;
}
print "\n";

# **************************************************************************
# FILE SYSTEM
# This performs checks prior to the compression of the files.-
# **************************************************************************
print " File Systems: \n";
for $key ( keys %{$table{handler}} ) {
	if ( $table{handler}{$key}{available} ) {
		$dirname = $table{handler}{$key}{location};

		# If File System is over $SIZE, then clean it.-
		&clean_dir($dirname,$SIZE);

		# Check File System size 
		$df = &mydf($dirname);
		printf " %-10s %-4s %-30s \n", $table{handler}{$key}{name}, $df."%", $dirname;
	}
}
print "\n";

# **************************************************************************
# DIRECTORY
# Now I am sure there's enough disk, so the backup is save.-
# This creates a sub-directory inside the handler. The name of 
# the sub-directory is set in the section above.-
# **************************************************************************
for $key ( keys %{$table{handler}} ) {
	if ( $table{handler}{$key}{available} ) {
		$dirname = $table{handler}{$key}{destination};
		`mkdir -p $dirname 2>/dev/null`;
		`ls $dirname` and die " Can't create $dirname!! \n"; 
	}
}

# **************************************************************************
# TAR 
# This crates a command that is not executed and is stored in the 
# @CMD array.- 
# **************************************************************************
my $i = 0;
my @CMD;
while ( defined $table{source}[$i]) {
	my $s 	= $table{source}[$i];
	my $cmd	= "";
	
	# List files.-
	# print Dumper $s->{dir};
	my $list = join(' ',@{$s->{dir}});
	
	# Compress.-
	$action = "";
	if ( $s->{compress} ) {
		$action = " tar -cvvf ./backup.tar $list ";
		$verify = " ls -la ./backup.tar ";
	} else { 
		$action = " cp -cvvf $list . ";
	}

	# For each handler.-
	$h = 0;
	while ( defined $s->{handler}[$h] and my $hn = $s->{handler}[$h]) {
		$kk = $table{handler}{$hn};
		if ( $kk->{available} ) {

			# If handler is available, then, Change to directory.-
			$dest = " $kk->{destination} ";

			# Print command.-
			$cmd = " cd $dest; $action; pwd; $verify; ";
			push @CMD, $cmd;

		}
	
		# Next handler.-
		$h++;
	}

	# Next source.-
	$i++;
}

# **************************************************************************
# BASH
# This executes all the commands created in the section above one 
# at a time. Each command represents a backup for each handler.-
# **************************************************************************
my $i = 0;
while ( defined $CMD[$i] ) {

	# Execute command.-
	print " $CMD[$i] \n\n";
	`$CMD[$i]` or die $!;

	# Next command.-
	$i++;
}

# **************************************************************************
# FUNCTIONS.-
# **************************************************************************

# Returns the size of a file system with the given directory name.-
sub mydf {
	$dirname = $_[0] or die;
	$df = `df -P $dirname | tail -1 | awk '{print \$5}' | sed 's/%//gi'`;
	chomp $df;
	return $df;
}

# Cleans a directory.-
sub clean_dir {
	$dirname = $_[0] or die;
	$size = $_[1] or die;
	$df = &mydf($dirname);
	my $i = 0;
	while ( $df > $size and $i < 10 ) {
		`unalias rm 2>/dev/null; ls -l $dirname 2>/dev/null | grep -v "????" | grep -v total | awk '{ print \$9}' | xargs -i{} rm -rf $dirname/{}`;
		$df = &mydf($dirname);
		chomp $df;
		$i++;
	}
	if ( $i >= 10 or $df > 80 ){
		die "Can't clean $dirname";
	}
}

# print Dumper \%table;
exit;
