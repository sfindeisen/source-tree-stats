#!/usr/bin/perl
#
# Directory tree statistics.
#
# Copyright (C) 2010 Stanislaw T. Findeisen <sf181257@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Changes history:
#
# 2010-07-08 (STF) Initial version.

use warnings;
use strict;
use integer;
use utf8;

use constant {
    FILENAME_SUFFIX_ALLOW => qr/^([-A-Za-z0-9\_\.]+)$/o,
    EMPTY_LINE => qr/^\s*$/,
    N_FILES    => 'N_FILES',
    N_LINES    => 'N_LINES',
    N_LINES_NE => 'N_LINES_NE',
    VERSION      => '0.1',
    VERSION_DATE => '2010-07-08'
};

use Getopt::Long;

####################################
# Global variables
####################################

my $verbose = 0;
my @fileNamePatterns = ();

####################################
# Common stuff
####################################

sub printPrefix {
    my $prefix  = shift;
    unshift(@_, $prefix);

    my $msg = join('', @_);
    chomp($msg);
    local $| = 1;
    print(STDERR "$msg\n");
}

sub prompt {
    my $msg = join('', @_);
    chomp ($msg);
    local $| = 1;
    print(STDERR $msg);

    my $ui = <STDIN>;
    chomp ($ui);
    return $ui;
}

sub debug {
    printPrefix('[debug]   ', @_) if ($verbose);
}

sub warning {
    printPrefix('[warning] ', @_);
}

sub error {
    printPrefix('[error]   ', @_);
}

sub info {
    printPrefix('[info]    ', @_);
}

sub fatal {
    error(@_);
    die(@_);
}

####################################
# File statistics
####################################

# Input is a comma separated filename suffix list
sub initFileNamePatterns {
    my $pattStr = shift;

    if ($pattStr) {
        my @patts = split(',', $pattStr);

        foreach my $pt (@patts) {
            if ($pt =~ FILENAME_SUFFIX_ALLOW) {
                debug("File name suffix: $pt");
            } else {
                warning("Weird file name suffix: $pt");
            }
            push @fileNamePatterns, qr/${pt}$/;
        }
    }
}

sub fileNameMatches {
    return 1 unless (@fileNamePatterns);
    my $fileName = shift;
    foreach my $p (@fileNamePatterns) {
        return 1 if ($fileName =~ $p);
    }
    return 0;
}

sub getLongestStringLength {
    my $as    = shift;
    my @as    = @{$as};
    my $mxLen = 0;

    foreach my $s (@as) {
        my $sLen = length($s);
        $mxLen = $sLen if ($mxLen < $sLen);
    }

    return $mxLen;
}

sub getFileStats {
    my $fname = shift;
    my $fh    = undef;
    my $lc    = 0;
    my $lcne  = 0;

    open($fh, '<', $fname) or fatal("Cannot open file($fname): $!");
    while (my $line = <$fh>) {
        $lcne++ if (not ($line =~ EMPTY_LINE));
        $lc++;
    }
    close($fh);

    # debug("File: $fname: $lcne/$lc non-empty lines") if ($lcne != $lc);
    my %fs = (N_LINES => $lc, N_LINES_NE => $lcne);
    return \%fs;
}

sub getTreeStats {
    my $gStats         = shift;  # global stats
    my $lStats         = shift;  # just this directory (no subdirs)
    my $recLevel       = shift;
    my $recLevelIndent = shift;
    my $dirName        = shift;
    my %cStats         = (N_FILES() => 0, N_LINES() => 0, N_LINES_NE() => 0);  # accumulated stats (this dir + subdirs)
    $lStats->{N_FILES()}    = 0;
    $lStats->{N_LINES()}    = 0;
    $lStats->{N_LINES_NE()} = 0;

    $gStats->{$dirName} = \%cStats;
    opendir(my $dh, $dirName) or fatal("Error opening directory: $dirName");
    my @dirItems = sort readdir($dh);
    my @dirFiles = grep {-f "$dirName/$_"} @dirItems;
    my $maxFileNameLen = 1 + getLongestStringLength(\@dirFiles);

    foreach my $item (@dirItems) {
        next if ('.' eq $item) or ('..' eq $item);
        my $itemFull = "$dirName/$item";

        if (-d $itemFull) {
            debug($recLevelIndent . "Entering: $item");
            my %subStatsLoca = ();
            getTreeStats($gStats, \%subStatsLoca, 1 + $recLevel, ('  ' . $recLevelIndent), $itemFull);
            my $itemStats = $gStats->{$itemFull};

            if (defined($itemStats)) {
                my $filesCnt   = $itemStats->{N_FILES()};
                my $linesCnt   = $itemStats->{N_LINES()};
                my $linesCntNe = $itemStats->{N_LINES_NE()};
                my $filesCntLoca   = $subStatsLoca{N_FILES()};
                my $linesCntLoca   = $subStatsLoca{N_LINES()};
                my $linesCntNeLoca = $subStatsLoca{N_LINES_NE()};
                $cStats{N_FILES()}    += $filesCnt;
                $cStats{N_LINES()}    += $linesCnt;
                $cStats{N_LINES_NE()} += $linesCntNe;
                my $msg2 = sprintf("Summary (%s): LOCAL: %d files; %d NE lines; %d lines", $item, $filesCntLoca, $linesCntNeLoca, $linesCntLoca);
                debug($recLevelIndent . $msg2);
                my $msg1 = sprintf("Summary (%s): TOTAL: %d files; %d NE lines; %d lines", $item, $filesCnt, $linesCntNe, $linesCnt);
                debug($recLevelIndent . $msg1);
            } else {
                warning("Error getting stats for subdirectory: $item");
            }
        } elsif ((-f $itemFull) and (fileNameMatches($itemFull))) {
            my $fileStats  = getFileStats($itemFull);
            my $linesCnt   = $fileStats->{N_LINES()};
            my $linesCntNe = $fileStats->{N_LINES_NE()};
            $lStats->{N_FILES()}    += 1;
            $lStats->{N_LINES()}    += $linesCnt;
            $lStats->{N_LINES_NE()} += $linesCntNe;

            my $msg = sprintf("%-${maxFileNameLen}s: %5d %5d", $item, $linesCntNe, $linesCnt);
            debug($recLevelIndent . $msg);
        }
    }

    closedir($dh);

    $cStats{N_FILES()}    += $lStats->{N_FILES()};
    $cStats{N_LINES()}    += $lStats->{N_LINES()};
    $cStats{N_LINES_NE()} += $lStats->{N_LINES_NE()};
}

sub printGlobalStats {
    my $stats        = shift;
    my $inputDirName = shift;
    my $inputDirNameLen = length($inputDirName);
    my %stats    = %{$stats};
    my @statKeys = sort (keys %stats);
    my $prefixOK = 1;

    # check for common dirname prefix:
    foreach my $key (@statKeys) {
        my $keyLen = length($key);

        if ($keyLen < $inputDirNameLen) {
            $prefixOK = 0;
            last;
        } else {
            my $keyPfx = substr($key, 0, $inputDirNameLen);
            if (($inputDirName ne $keyPfx) or (($keyLen > $inputDirNameLen) and (substr($key, $inputDirNameLen, 1) ne '/'))) {
                $prefixOK = 0;
                last;
            }
        }
    }

    my $maxDirNameLen  = getLongestStringLength(\@statKeys);
       $maxDirNameLen -= $inputDirNameLen if ($prefixOK);
    print("Found " . (scalar @statKeys) . " dirs ($inputDirName):\n");

    foreach my $key (@statKeys) {
        my $statsDir   = $stats{$key};
        my $filesCnt   = $statsDir->{N_FILES()};
        my $linesCnt   = $statsDir->{N_LINES()};
        my $linesCntNE = $statsDir->{N_LINES_NE()};
        my $dirNamePrn =  ($prefixOK ? (substr($key, $inputDirNameLen)) : $key);
           $dirNamePrn =~ s/\/+//o if ($prefixOK);  # strip leading /
           $dirNamePrn = '.' unless (length($dirNamePrn));

        my $msg = undef;
        if ($filesCnt) {
            $msg = sprintf("%-${maxDirNameLen}s: %7d/%7d lines in %6d files (%5d/%5d lines per file)", $dirNamePrn, $linesCntNE, $linesCnt, $filesCnt, ($linesCntNE/$filesCnt), ($linesCnt/$filesCnt));
        } else {
            $msg = sprintf("%-${maxDirNameLen}s: %7d/%7d lines in %6d files", $dirNamePrn, $linesCntNE, $linesCnt, $filesCnt);
        }
        # info($msg . (($inputDirName eq $key) ? ' (*)' : ''));
        print("$msg\n");
    }
}

####################################
# Help message
####################################

sub printHelp {
    my $ver           = VERSION();
    my $verdate       = VERSION_DATE();
    print <<"ENDHELP";
treeStats $ver ($verdate)

Copyright (C) 2010 Stanislaw T. Findeisen <sf181257\@gmail.com>
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/>
This is free software: you are free to change and redistribute it.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

Directory tree statistics. Following statistics are available:
* number of files
* number of lines (non-empty/all) (for plain files).

Usage (example):
  $0 --fileExt .java,.xml --verbose <dir>

fileExt is a comma-separated filename suffix filter (skip to
include all files).
ENDHELP
}

####################################
# The program - main
####################################

my $help  = 0;
my $fileNamePattern = '';
my $clres = GetOptions('fileExt:s' => \$fileNamePattern, 'help'  => \$help, 'verbose' => \$verbose);
my $inputDirName = shift @ARGV;

if (($help) or (not (($clres) and ($inputDirName)))) {
    printHelp();
    exit 0;
}

initFileNamePatterns($fileNamePattern);
my %stats = ();
getTreeStats(\%stats, {}, 0, '', $inputDirName);
printGlobalStats(\%stats, $inputDirName);
