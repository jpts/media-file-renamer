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
my %args = ('quiet' => false, 'noop' => false, 'recurse' => false);
my %output = ('movie' => '/---Movies---', 'tv' => '/---TV---', 'audio' => '/---Music---');
my $subs_dir = 'subs';
my @video_extns = ('.mp4','.avi','.mkv');
my @subs_extns = ('.srt');
my @audio_extns = ('.mp3','.flac');
my @crap_extns = ('.txt','.nfo','.jpg');
#my @actions;
my $sep = '/';
while ($arg = shift)
{
  switch($arg)
  {
    case '-i' {$args{input} = shift;}
    case '-h' {echoUsage();}
    case '-o' {$root = shift;}
    case '-q' {$args{quiet} = true;}
    case '-r' {$args{recurse} = true;}
    case '-t' {$args{media_type} = shift}
    case '--noop' {$args{noop} = true;}
    else {print 'Argument '.$arg.' not supported.'."\n";echoUsage();}
  }
}
print 'Root output directory: '.$root."\n";

if ( defined($args{input}) && -d $args{input} )
{
  unless ( defined($args{media_type}) )
  {
    $args{media_type} = getMediaType($args{input});
  }
  validateMediaType($args{media_type});
  processDir($args{input});
}
elsif ( defined($args{input}) && -f $args{input} )
{
  if ( defined($args{media_type}) )
  {
    validateMediaType($args{media_type});
    processFile($args{input});
  }
  else
  {
    quit('You must specify a media type with -t when using single files.');
  }
}
else
{
  quit('No valid input specified');
}

# Process file handle
sub processDir
{
  my $media_type = $args{media_type};
  my $dir = $_[0];
  opendir (DIR, $dir) or quit("$!");
  my @files = readdir DIR;
  foreach my $file (@files)
  {
    processFile($dir.$sep.$file);
  }
  # Delete empty dirs
  if ( scalar(grep { $_ ne "." && $_ ne ".." } readdir DIR) == 0 )
  {
    unless ($args{noop})
    {
      rmdir $dir or quit("$!");
    }
    unless ($args{quiet})
    {
      print "Removed directory: '$dir'\n";
    }
  }
}

# Process file
sub processFile
{
  my $media_type = $args{media_type};
  my ($name,$path,$suffix) = fileparse($_[0], qr/\.[^.]*/);
  my $old_file = $path.$name.$suffix;
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
    unless ($args{noop})
    {
      unless ( -d $new_path )
      {
        make_path($new_path);
      }
      # Something should perhaps check to see it already exists?
      move( $old_file, $new_path.$new_name.$new_suffix) or quit("Move failed: $!: $path");
    }
    my ($rel_path) = ($new_path =~ m/$root(.*)/);
    unless ($args{quiet})
    {
      print "Processed file: '$name$suffix' => '$rel_path$new_name$new_suffix'\n";
    }
    # my %hash = {'old' => }
    # push (@actions, "$dir);
  }
  elsif ($suffix ~~ @audio_extns && $media_type == 'audio')
  {
    # Process audio somehow.
  }
  elsif ($suffix ~~ @crap_extns)
  {
    my $bytes = stat($old_file)->size;
    my $mbytes = $bytes / 1048576;
    if ( $mbytes < 1)
    {
      unless ($args{noop})
      {
        unlink $old_file;
      }
      unless ($args{quiet})
      {
        print 'Deleted file: \''.$old_file. "'\n";
      }
    }
  }
  elsif ( $args{recurse} && -d $old_file )
  {
    processDir($old_file); 
  }
}

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
  if ( defined ($season) )
  {
    $fn = 'Season '.$season.$sep.$fn;
  }
  if ( defined ($show) )
  {
    $fn = $show.$sep.$fn;
  }

  return $fn;
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

# Check media type is valid
sub validateMediaType
{
  if ( $_[0] !~ m/(movie|tv|audio)/ )
  {
    quit('Invalid media type.');
  }
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
  my $avg_size;
  my @files;
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
  unless ( $args{quiet} )
  {
    print 'Media type: '.$type."\n";
    print 'Average file size: '.sprintf("%0.1f",$avg_size)."MB\n";
  }
  return $type;
}

# Usage Function
sub echoUsage
{
  my $usage = <<EOU;
  Usage:
    -i: Specify input directory / file to process
    -h: Show this usage message
    -o: Root media library path to write finished files
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
  if (!$args{quiet} && $_[0])
  {
    die $_[0]."\n";
  }
  else
  {
    exit;
  }
}
