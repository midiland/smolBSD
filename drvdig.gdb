define fstate
	# arg0 at 2 is enabled, 3 is disabled
	set $baseaddr = $arg1
	set $fstateaddr = $baseaddr + 10
	set {char}$fstateaddr = $arg0
end

define lookup
	x/s *$arg0
	x/6wx $arg0
end

define loop_cfdata
	set $ptr = (int *)&cfdata
	while (*$ptr != 0)
		printf "%x %s %s %x\n", $ptr, (char *)*$ptr, (char *)*($ptr + 1), *($ptr + 2)
		set $ptr = $ptr + 6
	end
end
