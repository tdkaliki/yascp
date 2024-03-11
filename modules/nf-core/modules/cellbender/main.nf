// Modules to include.
include {
    cellbender__rb__get_input_cells;
    cellbender__remove_background;
    cellbender__remove_background__qc_plots;
    cellbender__remove_background__qc_plots_2;
    cellbender__gather_qc_input;cellbender__preprocess_output;
} from "./functions.nf"

// Set default parameters.
outdir           = "${params.outdir}/nf-preprocessing"

workflow CELLBENDER {
    take:
        ch_experimentid_paths10x_raw
		    ch_experimentid_paths10x_filtered
        channel__metadata
        
    main:
  
        ch_experimentid_paths10x_raw.map{row -> tuple(
            row[0],
            file("${row[1]}/barcodes.tsv.gz"),
            file("${row[1]}/features.tsv.gz"),
            file("${row[1]}/matrix.mtx.gz")
        )}.set{channel__file_paths_10x}

        ch_experimentid_paths10x_raw.map{row -> 
            row[0]}.set{experiment_id_in}
        experiment_id_in.subscribe { println "experiment_id_in: $it" }
        experiment_id_in = experiment_id_in.view()
        outdir =  outdir+'/cellbender'
        
        // here pass in the number of cells detected by cellranger/ 
        if (params.cellbender_rb.estimate_params_umis.value.method_estimate_ncells=='expected'){
            channel__metadata.splitCsv(header: true, sep: "\t", by: 1).map{row -> tuple(
                row.experiment_id,
                row.Estimated_Number_of_Cells,
            )}.set{ncells_cellranger_pre}
        }else{
            channel__metadata.splitCsv(header: true, sep: "\t", by: 1).map{row -> tuple(
                row.experiment_id,
                '0',
            )}.set{ncells_cellranger_pre}
        }

        ncells_cellranger_pre.join(ch_experimentid_paths10x_raw, remainder: false).set{post_ncells_cellranger} 
        post_ncells_cellranger.map{row -> tuple(row[0], row[1])}.filter{ it[2] == null }.set{ncells_cellranger}
        channel__file_paths_10x.combine(ncells_cellranger, by: 0).set{channel__file_paths_10x_with_ncells}
       
        cellbender__rb__get_input_cells(
            outdir,
            channel__file_paths_10x_with_ncells,
            params.cellbender_rb.estimate_params_umis.value,
        )
        
        // Correct counts matrix to remove ambient RNA
    // Some samples may fail with the defaults. Hence here we allow for a changes to be applied. 

    
    
    
    
        epochs_to_use = params.cellbender_rb.epochs.value
        learning_rate_to_use = params.cellbender_rb.learning_rate.value
        zdims_to_use = params.cellbender_rb.zdim.value
        zlayers_to_use = params.cellbender_rb.zlayers.value
        low_count_threshold_to_use = params.cellbender_rb.low_count_threshold.value

        cellbender__remove_background(
            outdir,
            cellbender__rb__get_input_cells.out.cb_input,
            epochs_to_use,
            learning_rate_to_use,
            zdims_to_use,
            zlayers_to_use,
            low_count_threshold_to_use,
            params.cellbender_rb.fpr.value
        )



        cellbender__preprocess_output(
            cellbender__remove_background.out.cleanup_input,
            cellbender__remove_background.out.cb_plot_input,
            cellbender__remove_background.out.experimentid_outdir_cellbenderunfiltered_expectedcells_totaldropletsinclude,
        )


        cellbender__preprocess_output.out.experimentid_outdir_cellbenderunfiltered_expectedcells_totaldropletsinclude
            .combine(ch_experimentid_paths10x_raw, by: 0)
            .combine(ch_experimentid_paths10x_filtered, by: 0)
            .combine(Channel.from("${params.cellbender_rb.fpr.value}"
                    .replaceFirst(/]$/,"")
                    .replaceFirst(/^\[/,"")
                    .split()))
            .set{input_channel_qc_plots_2}
            
            cellbender__remove_background__qc_plots_2(input_channel_qc_plots_2,outdir)
            

        results_list = cellbender__preprocess_output.out.out_paths
        // prepeare the output channel for utilising in the deconvolution instead of barcode input.
        cellbender_path = cellbender__preprocess_output.out.alternative_input
        cellbender_downstream = cellbender__remove_background.out.cb_to_use_downstream
        emit:
            // results_list //results list is not needed to be emited - if done it will wait for all the cellbender stuff to finish.
            cellbender_path
            cellbender_downstream

            
}

