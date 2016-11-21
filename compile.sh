#! /bin/sh --
# by pts@fazekas.hu at Mon Nov 21 13:58:01 CET 2016

set -ex

test -f openssl-0.9.8zh.tar.gz
rm -rf openssl-0.9.8zh
export CC='xstatic gcc'
$CC -v

tar xzvf openssl-0.9.8zh.tar.gz
cd openssl-0.9.8zh
./Configure no-shared linux-elf no-dso
# openssl uses SSE2 instructions (-DOPENSSL_IA32_SSE2), so
# -march=nocona, -march=core2, -march=corei7, -march=atom is needed;
# -march=i686 is not enough.
# -DOPENSSL_BN_ASM_PART_WORDS -DOPENSSL_IA32_SSE2 -DSHA1_ASM -DMD5_ASM -DRMD160_ASM -DAES_ASM
perl -pi~ -e 's@\s(?:-g|-arch\s+\S+)(?!\S)@@g, s@\s-O\d*(?!\S)@ -O3 -march=core2 -ffunction-sections -fdata-sections -Wl,--gc-sections@g, s@\s-D(DSO_DLFCN|HAVE_DLFCN_H)(?!\S)@@g if s@^CFLAG\s*=\s*@CFLAG = @' Makefile
# Workaround for our perl not supporting -I... and PERLINC=...
ln -s . crypto/des/asm/perlasm
make build_libs
make build_apps  # Creates apps/openssl .
cp -a apps/openssl openssl-core2.static
sstrip.static openssl-core2.static

# elfosfix.pl .
perl -we '
use integer;
use strict;
my $from_oscode=0; # $ELF_os_codes{"SYSV"};
my $to_oscode=3;  # $ELF_os_codes{"GNU/Linux"};

for my $fn (@ARGV) {
  my $f;
  if (!open $f, "+<", $fn) {
    print STDERR "$0: $fn: $!\n";
    next
  }
  my $head;
  # vvv Imp: continue on next file instead of die()ing
  die if 8!=sysread($f,$head,8);
  if (substr($head,0,4)ne"\177ELF") {
    print STDERR "$0: $fn: not an ELF file\n";
    close($f); next;
  }
  if (vec($head,7,8)==$to_oscode) {
    print STDERR "$0: info: $fn: already fixed\n";
  }
  if ($from_oscode!=$to_oscode && vec($head,7,8)==$from_oscode) {
    vec($head,7,8)=$to_oscode;
    die if 0!=sysseek($f,0,0);
    die if length($head)!=syswrite($f,$head);
  }
  close($f);
}' openssl-core2.static

cp -a openssl-core2.static ../
cd ..
ls -l openssl-core2.static

: compile.sh OK.
