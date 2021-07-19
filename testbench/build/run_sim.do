vlog -sv -f sha256_sim.flist

vsim -voptargs=+acc sha256_topsim -wlf vsim.wlf -l vsim.log
log * -r
