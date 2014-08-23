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
my $root = '/media';
my $arg;
my %args = ('quiet' => false, 'noop' => false, 'recurse' => false);
my %output = ('movie' => '/data2/movies', 'tv' => '/data1/shares/torrents/TV-Series', 'audio' => '/data1/shares/torrents/Music');
my $subs_dir = 'subs';
my @video_extns = ('.mp4','.avi','.mkv');
my @subs_extns = ('.srt');
my @audio_extns = ('.mp3','.flac', '.wav');
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

# check for directory input
if ( defined($args{input}) && -d $args{input} )
{
  unless ( defined($args{media_type}) )
  {
    $args{media_type} = getMediaType($args{input});
  }
  validateMediaType($args{media_type});
  processDir($args{input});
}
# check for file input
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
  # look for video files
  if (($suffix ~~ @video_extns || $suffix ~~ @subs_extns) && ($media_type eq 'movie' || $media_type eq 'tv' ))
  {
    my $file_clean;
    my $fn;
    if ($media_type eq 'movie')
    {
      # $file_clean = cleanMovieFileName($name).$suffix;
      $fn = getMovieName($name);
      $file_clean = cleanFileName($fn).$suffix;

    }
    elsif ($media_type eq 'tv')
    {
      # $file_clean = cleanTvFileName($name).$suffix;
      my $tv_name = getTVName($name);
      $fn = cleanFileName($tv_name);
      my ($tv_sid, $tv_eid) = getTVID($name);
      $file_clean = $fn.$sep."Season $tv_sid".$sep.$fn." - S".$tv_sid."E".$tv_eid.$suffix;
    }
    # deal with sub file
    # TODO deal with multiple sub files
    if ($suffix ~~ @subs_extns)
    {
      $file_clean = $subs_dir.$sep.$file_clean;
    }
    # piece filename back into correct pieces
    my ($new_name,$new_path,$new_suffix) = fileparse($root.$output{$media_type}.$sep.$file_clean, qr/\.[^.]*/);
    # make sure we're not it no-operate mode
    unless ($args{noop})
    {
      # make directory if it doesnt exist
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
  # Process audio somehow.
  elsif ($suffix ~~ @audio_extns && $media_type == 'audio')
  {
    quit('Audio processing currently unhandled.');
  }
  # Discard other files
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
  # Process a directory
  elsif ( $args{recurse} && -d $old_file )
  {
    processDir($old_file); 
  }
}

# Get movie name - split on year
sub getMovieName
{
  my $fn = $_[0];
  if ( $fn =~ /(.*)[\[(.]([\d]{4})[\]).]/ )
  {
    return "$1 \[$2\]";
  }
  else
  {
    quit('Failed to get movie name');
  }
}

# Get TV name - split on Series / Episode etc
sub getTVName
{
  my $fn = $_[0];
  if ( $fn =~ /(.*)s\d\de\d\d/i )
  {
     return $1;
  }
  elsif ( $fn =~ /(.*)\dx\d\d/ )
  {
    return $1;
  }
  elsif ( $fn =~ /(.*)Season/ )
  {
    return $1;
  }
  else
  {
    return -1;
  }
}

# Get TV ID
sub getTVID
{
  my $fn = $_[0];
  if ( $fn =~ /s((?:\d){0,1}\d)e(\d\d)/i )
  {
     return ($1,$2);
  }
  elsif ( $fn =~ /(\d)x(\d\d)/ )
  {
    return ($1,$2);
  }
  elsif ( $fn =~ /Season ((?:\d){0,1}\d)/i )
  {
    my $SID = $1;
    if ( $fn =~ /Episode ((?:\d){0,1}\d)/i )
    {
      return ($SID,$1);
    }
    else
    {
      return -1;
    }
  }
  else
  {
    return -1;
  }
}

# Common filename cleaning regex
sub cleanFileName
{
  my $fn = $_[0];
  # Remove unwanted chars
  $fn =~ s/[._-]/ /g;
  # Remove unwanted words
  #$fn =~ s/[\s]*(xvid|divx|brrip|dvd|\wdtv|mkv|ac3|default).*//ig;
  # Remove unwanted space
  $fn =~ s/[\s]+/ /g;
  # Convert case to Title Style
  $fn =~ s/\b([a-zA-Z])([a-zA-Z]*)/\U$1\L$2/g;
  # Strip lead/trailing whitespace
  $fn =~ s/^[ \s]+|[ \s]+$//g;

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

# media categorising fn
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
