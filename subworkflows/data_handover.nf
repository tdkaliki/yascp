include { GATHER_DATA } from '../modules/nf-core/modules/gather_data/main'
include { SUMMARY_STATISTICS_PLOTS } from '../modules/nf-core/modules/summary_statistics_plots/main'

workflow data_handover{
    take:
        outdir
        qc_input
        
        
    main:
        log.info 'running data handover'
        GATHER_DATA(outdir)
        SUMMARY_STATISTICS_PLOTS(outdir,GATHER_DATA.out.outfiles_dataset)
        // We also generate a report.

        // If we run it in sanger we transfer the data to the local website.
        
}