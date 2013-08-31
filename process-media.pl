#!/usr/bin/perl
use strict;
use warnings;
use Switch;
use File::Basename;
use File::Copy qw(move);
use File::stat;
use File::Path qw(make_path);
use constant false => 0;
use constant true  => 1;
my $argc = scalar @ARGV;
if ($argc == 0)
{
  echoUsage();
}
#print $argc." arguments passed: \n";
my $root = '/media/data/shares/torrents';
my $arg;
my $quiet = false;
my $file;
my $dir;
my %output = ('movie' => '/---Movies---', 'tv' => '/---TV---', 'audio' => '/---Music---');
my $subs_dir = 'subs';
my @files;
my $success = false;
my $noop = false;
my @video_extns = ('.mp4','.avi','.mkv');
my @subs_extns = ('.srt');
my @audio_extns = ('.mp3','.flac');
my @crap_extns = ('.txt','.nfo','.jpg');
my $avg_size;
my $media_type;
my $recurse = false;
#my @actions;
my $sep = '/';
while ($arg = shift)
{
  #print $arg."\n";
  switch($arg)
  {
    case '-d' {$dir = shift;}
    case '-h' {echoUsage();}
    case '-f' {$file = shift;}
    #case '-o' {$output = shift;}
    case '-q' {$quiet = true;}
    case '-r' {$recurse = true;}
    case '-t' {$media_type = shift}
    case '--noop' {$noop = true;}
    else {print 'Argument '.$arg.' not supported.'."\n";echoUsage();}
  }
}
print 'Media Sorter / Renaming Script.'."\n";
print 'Root output directory: '.$root."\n";

if ( defined($media_type) )
{
  if ( $media_type !~ m/(movie|tv|audio)/ )
  {
    quit('Invalid media type.');
  }
}
else
{
  $media_type = getMediaType($dir);
}

if ( defined($file) && defined($dir) )
{
  quit('Cannot parse file and directory simultaneously. Please specify only one.');
}
elsif ( defined($dir) && -d $dir )
{
  print 'Media type: '.$media_type."\n";
  if ( defined($avg_size) )
  {
    print 'Average file size: '.sprintf("%0.1f",$avg_size)."MB\n";
  }
  $success = opendir (DIR, $dir) or die "$!";
  @files = readdir DIR;
  foreach my $file (@files)
  {
    my ($name,$path,$suffix) = fileparse($file, qr/\.[^.]*/);
    if (($suffix ~~ @video_extns || $suffix ~~ @subs_extns) && ($media_type eq 'movie' || $media_type eq 'tv' ))
    {
      my $file_clean;
      if ($media_type eq 'movie')
      {
        $file_clean = cleanMovieFileName($name).$suffix;
      }
      elsif ($media_type eq 'tv')
      {
        $file_clean = cleanTvFileName($name).$suffix;
      }
      if ($suffix ~~ @subs_extns)
      {
        $file_clean = $subs_dir.$sep.$file_clean;
      }
      my ($new_name,$new_path,$new_suffix) = fileparse($root.$output{$media_type}.$sep.$file_clean, qr/\.[^.]*/);
      if (!$noop)
      {
        unless ( -d $new_path )
        {
          make_path($new_path);
        }
        move( $dir.'/'.$name.$suffix, $new_path.$new_name.$new_suffix) or die 'Move failed: ' . $!;
      }
      my ($rel_path) = ($new_path =~ m/$root(.*)/);
      print 'Processed file: \''.$file.'\' => \''.$rel_path.$new_name.$new_suffix."'\n";
      # my %hash = {'old' => }
      # push (@actions, "$dir);
    }
    elsif ($suffix ~~ @audio_extns && $media_type == 'audio')
    {
      # Process audio somehow.
    }
    elsif ($suffix ~~ @crap_extns)
    {
      my $bytes = stat($dir.$sep.$file)->size;
      my $mbytes = $bytes / 1048576;
      if ( $mbytes < 1)
      {
        unless ($noop)
        {
          unlink $dir.$sep.$file;
        }
        print 'Deleted file: \''.$file. "'\n";
      }
    }
    elsif ( $recurse && -d $file )
    {
      # Call dir process
    }
  }
  #Delete empty dirs
}
elsif ( defined($file) && -e $file )
{
  my ($name,$path,$suffix) = fileparse($file);
  $files[0] = $name;
  $dir = $path;
}
else
{
  quit('No directory or file specified');
}

if ($success)
{
  closedir DIR;
}
exit;

# Clean tv file name
sub cleanTvFileName
{
  my $fn = $_[0];
  $fn =~ s/[._-]/ /g;
  # Format seasons / episodes correctly
  $fn =~ s/[\s]*(Episode|e(\d\d[^\d]))[\s]*/E$2/i;
  $fn =~ s/(Season|Series)[\s]*/S/i;
  $fn =~ s/([\d]{1,2})x([\d]{1,2})/S$1E$2/i;
  $fn =~ s/([SE])[0]{0,1}(\d)([^\d])/${1}0$2$3/ig;
  # Remove dates
  $fn =~ s/([\d]{4})//g;
  # Remove things in brackets
  $fn =~ s/[\s]*[{\[(].*[\])}]//g;
  # Genric clean 
  $fn = cleanFileName($fn);
  # Add hyphens back in
  $fn =~ s/(\sS\d\dE\d\d)/ -$1/i;
  $fn =~ s/(\sS\d\dE\d\d\s)/$1- /i;
  # Determine show / season
  my ($show) = ($fn =~ m/(.*?) - (?:.*)/);
  my ($season) = ($fn =~ m/(?:.*) - S(\d\d)E\d\d(?:.*)/);
  if ( defined ($season))
  {
    $season = 'Season '.$season;
  }

  return $show.$sep.$season.$sep.$fn;
}

# Clean movie file name
sub cleanMovieFileName
{
  my $fn = $_[0];
  $fn = cleanFileName($fn);
  $fn =~ s/[\s]*[^\[][(]*([\d]{4})[)]*[\s]*/ \[$1\]/;
  $fn =~ s/\(.*\)//g;
  $fn =~ s/(.*)(\[[\d]{4}\])(?:.*)$/$1$2/;

  return $fn;
}

# Common filename cleaning regex
sub cleanFileName
{
  my $fn = $_[0];
  # Remove unwanted chars
  $fn =~ s/[._-]/ /g;
  # Remove unwanted words
  $fn =~ s/[\s]*(xvid|divx|brrip|dvd|\wdtv|mkv|ac3|default).*//ig;
  # Remove unwanted space
  $fn =~ s/[\s]+/ /g;
  # Convert case to Title Style
  $fn =~ s/\b([a-zA-Z])([a-zA-Z]*)/\U$1\L$2/g;

  return $fn;
}

# y/n user confirmation fn
sub getConfirmation
{
  my $msg = $_[0];
  print $msg . "\n";
  my $input;
  while ( $input !~ m/(y|n)/ )
  {
    print $msg . " (y/n)\n";
    chomp ( $input = <> );
  }
  if ( $input == 'y' )
  {
    return 1;
  }
  elsif ( $input == 'n' )
  {
    return 0;
  }
  die 'Invalid input.';
}

# media categorisiing fn
sub getMediaType
{
  my $dir_path = $_[0];
  my @media_files;
  my $count = 0;
  my $total_size = 0;
  my $type;
  opendir (MDIR, $dir_path) or die "$!";
  @files = readdir MDIR;
  foreach my $file (@files)
  {
    my $bytes = stat($dir_path.'/'.$file)->size;
    my $mbytes = $bytes / 1048576;
    if ( $mbytes > 1)
    {
      $count++;
      $total_size += $mbytes;
    }
  }
  closedir MDIR;
  if ( $count == 0 )
  {
    return 'empty';
  }
  $avg_size = $total_size / $count;
  if ( $avg_size < 70 )
  {
    $type = 'music';
  }
  elsif ( $avg_size > 70 && $avg_size < 450 )
  {
    $type = 'tv';
  }
  elsif ( $avg_size > 450 )
  {
    $type = 'movie';
  }
  else
  {
    $type = 'other';
  }
  return $type;
}

# Usage Function
sub echoUsage
{
  my $usage = <<EOU;
  Usage:
    -d: Specify directory to scan and process
    -h: Show this usage message
    -f: Specify input file to process
    -o: Path to put finished files
    -r: Enable recursive directory tranversing
    -t: Specify directory type. Overides detection
    -q: Quiet; no output
    --noop: Do not operate on files
EOU
  print $usage;
  exit;
}

# Function to deal with quiting nicely based upon environment
sub quit
{
  if (!$quiet && $_[0])
  {
    die $_[0]."\n";
  }
  else
  {
    exit;
  }
}
