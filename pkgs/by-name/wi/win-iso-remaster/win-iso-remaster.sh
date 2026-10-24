usage() {
  cat <<'EOF'
Usage: win-iso-remaster [options] <windows.iso>

Remasters a Windows 11 ISO so that UEFI boots without the "Press any key to
boot from CD or DVD" prompt, and Setup installs Windows 11 Pro without offering
the edition list (sources/ei.cfg).

Options:
  -o, --output FILE  output ISO (default: next to the source, *_pro_noprompt.iso,
                     or *_noprompt.iso with --noprompt-only)
  --pid KEY          also write sources/PID.txt with this product key
  --no-bios-prompt   remove boot/bootfix.bin so the BIOS boot skips its prompt
                     (unverified on hardware)
  --noprompt-only    no extraction and no ei.cfg: copy the ISO and replace the
                     UEFI boot image efisys.bin with efisys_noprompt.bin in place
  -h, --help         show this help
EOF
}

die() {
  echo "win-iso-remaster: $*" >&2
  exit 1
}

mode=rebuild
output=
pid=
no_bios_prompt=0

while (($#)); do
  case $1 in
    -o | --output)
      output=${2:?"$1 needs a file"}
      shift 2
      ;;
    --pid)
      pid=${2:?"--pid needs a key"}
      shift 2
      ;;
    --no-bios-prompt)
      no_bios_prompt=1
      shift
      ;;
    --noprompt-only)
      mode="patch"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage >&2
      die "unknown option: $1"
      ;;
    *)
      break
      ;;
  esac
done

(($# == 1)) || {
  usage >&2
  exit 2
}

if [[ $mode == patch ]] && [[ -n $pid || $no_bios_prompt == 1 ]]; then
  die "--pid and --no-bios-prompt need a rebuild, not --noprompt-only"
fi

src=$(realpath -- "$1")
[[ -f $src ]] || die "not a file: $1"
src_dir=$(dirname -- "$src")
src_base=$(basename -- "$src")
src_stem=${src_base%.*}

if [[ $mode == patch ]]; then
  suffix=_noprompt.iso
else
  suffix=_pro_noprompt.iso
fi
out=${output:-$src_dir/$src_stem$suffix}
out_dir=$(dirname -- "$out")
[[ -d $out_dir ]] || die "output directory does not exist: $out_dir"
out_dir=$(realpath -- "$out_dir")
out=$out_dir/$(basename -- "$out")
[[ $out != "$src" ]] || die "output would overwrite the source ISO"
[[ ! -e $out ]] || die "refusing to overwrite existing $out"

iso_size=$(stat -c %s -- "$src")
free=$(df --output=avail -B1 -- "$out_dir" | tail -n 1)
((free >= 2 * iso_size)) || die "need 2x the ISO size free in $out_dir ($((2 * iso_size)) bytes), have $free"

# The work dir lives next to the output, so the final move is a rename and the
# space check above covers it.
work=$(mktemp -d -- "$out_dir/.win-iso-remaster.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
trap 'exit 1' INT TERM HUP

if [[ $mode == patch ]]; then
  # Read the UEFI El Torito entry rather than assuming the LBA: Microsoft's
  # layout puts it at sector 555 today, but the catalog is the authority.
  lba=$(xorriso -indev "$src" -report_el_torito plain 2>/dev/null | awk '$7 == "UEFI" { print $NF }')
  [[ $lba =~ ^[0-9]+$ ]] || die "no UEFI El Torito entry in $src"

  7z e -y "-o$work" -- "$src" efi/microsoft/boot/efisys.bin efi/microsoft/boot/efisys_noprompt.bin >"$work/7z.log" ||
    die "7z could not extract the UEFI boot images, see $work/7z.log"

  size=$(stat -c %s -- "$work/efisys.bin")
  ((size % 2048 == 0)) || die "efisys.bin is not a whole number of sectors"
  [[ $size == "$(stat -c %s -- "$work/efisys_noprompt.bin")" ]] ||
    die "efisys_noprompt.bin has a different size than efisys.bin"

  dd if="$src" of="$work/extent.bin" bs=2048 skip="$lba" count="$((size / 2048))" status=none
  cmp -s -- "$work/efisys.bin" "$work/extent.bin" ||
    die "UEFI boot image at LBA $lba is not efisys.bin, refusing to patch"

  cp --reflink=auto -- "$src" "$work/out.iso"
  dd if="$work/efisys_noprompt.bin" of="$work/out.iso" bs=2048 seek="$lba" conv=notrunc status=none
  dd if="$work/out.iso" of="$work/patched.bin" bs=2048 skip="$lba" count="$((size / 2048))" status=none
  cmp -s -- "$work/efisys_noprompt.bin" "$work/patched.bin" || die "patched UEFI boot image does not match"
else
  tree=$work/tree
  mkdir -- "$tree"
  7z x -y "-o$tree" -- "$src" >"$work/7z.log" ||
    die "7z could not extract $src, see $work/7z.log"
  # Extracted UDF entries keep their read-only attributes.
  chmod -R u+w -- "$tree"
  [[ -d $tree/sources ]] || die "no sources/ directory in $src"

  if ((no_bios_prompt)); then
    rm -f -- "$tree/boot/bootfix.bin"
  fi
  if [[ -n $pid ]]; then
    printf '[PID]\nValue=%s\n' "$pid" >"$tree/sources/PID.txt"
  fi
  printf '[EditionID]\nProfessional\n[Channel]\nRetail\n[VL]\n0\n' >"$tree/sources/ei.cfg"

  volid=$(isoinfo -d -i "$src" | sed -n 's/^Volume id: //p')
  [[ -n $volid ]] || die "could not read the volume id of $src"

  # The recipe of dockur/windows (src/image.sh), except -boot-info-table, which
  # Microsoft's etfsboot.com does not use. genisoimage writes UDF, which the
  # Windows install image needs: install.wim is larger than 4 GiB.
  (
    cd -- "$tree"
    genisoimage -quiet -o "$work/out.iso" \
      -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 -c boot.catalog \
      -iso-level 4 -J -l -D -N -joliet-long -relaxed-filenames \
      -V "$volid" -udf -allow-limited-size \
      -eltorito-alt-boot -efi-boot efi/microsoft/boot/efisys_noprompt.bin -no-emul-boot \
      .
  ) || die "genisoimage failed"
fi

mv -- "$work/out.iso" "$out"
echo "wrote $out"
xorriso -indev "$out" -report_el_torito plain 2>/dev/null | grep 'El Torito boot img' || true
