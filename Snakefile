#########################################
# Snakemake pipeline for RNA-Seq analysis
#########################################

###########
# Libraries
###########
import pandas as pd
import os

###############
# Configuration
###############

configfile: "data/config.yaml" # where to find parameters
WORKING_DIR = config["working_dir"]
RESULT_DIR = config["result_dir"]
THREADS = config["threads"]
########################

# Edited
# read the tabulated separated table containing the sample, condition and fastq file information∂DE
units = pd.read_excel(config["units"], sheet_name = "samples", dtype = str, engine = 'openpyxl').set_index(["fastq-file-name"], drop=False)
units.index.names = ['sample']
units.index = units.index.str.replace('.fq', '')
units.index = units.index.str.replace('.gz', '')
units.index = units.index.str.replace('.fastq', '')
units.index = units.index.str.replace('.txt', '')
units.dropna(inplace = True)

# create lists containing the sample names and conditions
SAMPLES = units.index.get_level_values('sample').unique().tolist()
samples = units.drop(units.columns[0], axis=1)

# ----------------------------

        # # read the tabulated separated table containing the sample, condition and fastq file information∂DE
        # units = pd.read_table(config["units"], dtype=str).set_index(["sample"], drop=False)

        # # create lists containing the sample names and conditions
        # SAMPLES = units.index.get_level_values('sample').unique().tolist()
        # samples = pd.read_csv(config["units"], dtype=str,index_col=0,sep="\t")

###########################
# Input functions for rules
###########################

def sample_is_single_end(sample):
    """This function detect missing value in the column 2 of the units.tsv"""
    if "fq2" not in samples.columns:
        return True
    else:
        return pd.isnull(samples.loc[(sample), "fq2"])

def get_fastq(wildcards):
    """ This function checks if the sample has paired end or single end reads
    and returns 1 or 2 names of the fastq files """
    if sample_is_single_end(wildcards.sample):
        return samples.loc[(wildcards.sample), ["fq1"]].dropna()
    else:
        return samples.loc[(wildcards.sample), ["fq1", "fq2"]].dropna()

def get_trimmed(wildcards):
    """ This function checks if sample is paired end or single end
    and returns 1 or 2 names of the trimmed fastq files """
    if sample_is_single_end(wildcards.sample):
        return WORKING_DIR + "trimmed/" + wildcards.sample + "_R1_trimmed.fq.gz"
    else:
        return [WORKING_DIR + "trimmed/" + wildcards.sample + "_R1_trimmed.fq.gz", WORKING_DIR + "trimmed/" + wildcards.sample + "_R2_trimmed.fq.gz"]

#################
# Desired outputs
#################
rule all:
    input:
#        expand(RESULT_DIR + "fastqc/{sample}_fastqc.html", sample=SAMPLES),
        WORKING_DIR + "genome/genome.gtf",
        RESULT_DIR + 'gene_FPKM.csv',
        RESULT_DIR + "counts.txt",
        RESULT_DIR + "multiqc/multiqc_report.html"
    message:
        "Job done!"

#######
# Rules
#######

##################################
# Fastp
##################################

rule fastp:
    input:
        get_fastq
    output:
        fq1  = temp(WORKING_DIR + "trimmed/" + "{sample}_R1_trimmed.fq.gz"),
        fq2  = temp(WORKING_DIR + "trimmed/" + "{sample}_R2_trimmed.fq.gz"),
        html = RESULT_DIR + "fastp/{sample}.html"
    message:"trimming {wildcards.sample} reads"
    threads: THREADS
    priority: 10
    log:
        RESULT_DIR + "logs/fastp/{sample}.log.txt"
    params:
        sampleName = "{sample}",
        qualified_quality_phred = config["fastp"]["qualified_quality_phred"]
    run:
        if sample_is_single_end(params.sampleName):
            shell("fastp --thread {threads} --html {output.html} \
            --qualified_quality_phred {params.qualified_quality_phred} \
            --in1 {input} --out1 {output.fq1} 2> {log}; \
            touch {output.fq2}")
        else:
            shell("fastp --thread {threads} --html {output.html} \
            --qualified_quality_phred {params.qualified_quality_phred} \
            --detect_adapter_for_pe \
            --in1 {input[0]} --in2 {input[1]} --out1 {output.fq1} --out2 {output.fq2} 2> {log}")

#rule fastqc:
#    input:
#        get_fastq
#    output:
#        html1 = RESULT_DIR + "fastqc/{sample}_fastqc.html"
#    threads: THREADS
#    params:
#        sampleName = "{sample}",
#        path = RESULT_DIR + "fastqc/"
#    run:
#        if sample_is_single_end(params.sampleName):
#            shell("fastqc -t {threads} {input[0]} --outdir={params.path}")
#        else:
#            shell("fastqc -t {threads} {input[0]} {input[1]} --outdir={params.path}")
#           

#########################
# RNA-Seq read alignement
#########################
# if config["need_indexed"].upper().find("NEED") >= 0:
#     if config["organism"].upper().find("HOMO") >= 0 or config["organism"].upper().find("HUMAN") >= 0:
#         rule ref_download_hg:
#             output:
#                 fasta = WORKING_DIR + "genome/genome.fa",
#                 gtf = WORKING_DIR + "genome/genome.gtf"
#             params:
#                 version = config["ref"]["hg_release_ver"], # release version, It must be string
#                 outdir = WORKING_DIR + "genome/"
#             shell:"""
#             mkdir -p {params.outdir} && \
#             wget ftp://ftp.ensembl.org/pub/release-{params.version}/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz -O genome.fa.gz && gunzip -c genome.fa.gz > {output.fasta} && \
#             wget ftp://ftp.ensembl.org/pub/release-{params.version}/gtf/homo_sapiens/Homo_sapiens.GRCh38.{params.version}.gtf.gz -O genome.gtf.gz && gunzip -c genome.gtf.gz > {output.gtf}"""
#     elif config["organism"].upper().find("MUS") >= 0 or config["organism"].upper().find("MOUSE") >= 0:
#         rule ref_download_mm:
#             output:
#                 fasta = WORKING_DIR + "genome/genome.fa",
#                 gtf = WORKING_DIR + "genome/genome.gtf"
#             params:
#                 version = config["ref"]["mm_release_ver"], # release version, It must be string
#                 outdir = WORKING_DIR + "genome/"
#             shell:"""
#             mkdir -p {params.outdir} && \
#             wget ftp://ftp.ensembl.org/pub/release-{params.version}/fasta/mus_musculus/dna/Mus_musculus.GRCm38.dna.primary_assembly.fa.gz -O genome.fa.gz && tar -zxvf genome.fa.gz -C {params.outdir} && \
#             wget ftp://ftp.ensembl.org/pub/release-{params.version}/gtf/mus_musculus/Mus_musculus.GRCm38.{params.version}.gtf.gz -O genome.gtf.gz && tar -zxvf genome.gtf.gz -C {params.outdir}"""


if config["aligner"].upper().find("HISAT2") >= 0:
    if config["organism"].upper().find("HOMO") >= 0 or config["organism"].upper().find("HUMAN") >= 0:
        ref_ver = config["ref"]["hg_release_ver"]
    elif config["organism"].upper().find("MUS") >= 0 or config["organism"].upper().find("MOUSE") >= 0:
        ref_ver = config["ref"]["mm_release_ver"]

    if config["need_indexed"].upper().find("NEED") >= 0:
        rule hisat_index:
            output:
                [WORKING_DIR + "genome/genome." + str(i) + ".ht2" for i in range(1,9)],
                WORKING_DIR + "genome/genome.gtf"
            message:
                "indexing genome"
            params:
                WORKING_DIR + "genome/",
                ref_ver
            threads: THREADS
            run:
                if config["organism"].upper().find("HOMO") >= 0 or config["organism"].upper().find("HUMAN") >= 0:
                    shell("cp scripts/make_grch38_tran.sh {params[0]} && sh temp/genome/make_grch38_tran.sh {params[1]} {threads}")
                elif config["organism"].upper().find("MUS") >= 0 or config["organism"].upper().find("MOUSE") >= 0:
                    shell("cp scripts/make_grcm38_tran.sh {params[0]} && sh temp/genome/make_grcm38_tran.sh {params[1]} {threads}")

    rule hisat_mapping:
        input:
            get_trimmed,
            indexFiles = [WORKING_DIR + "genome/genome." + str(i) + ".ht2" for i in range(1,9)]
        output:
            bams = temp(WORKING_DIR + "mapped/{sample}.sorted.bam"),
            log  = RESULT_DIR + "logs/hisat2/{sample}_log.txt"
        params:
            indexName = WORKING_DIR + "genome/genome",
            sampleName = "{sample}"
        message:
            "mapping reads to genome to bam files."
        threads: THREADS
        run:
            if sample_is_single_end(params.sampleName):
                shell("hisat2 -p {threads} --summary-file {output.log} -q -x {params.indexName} \
                -U {input[0]} | samtools view -@ {threads} -Sb -F 4 | samtools sort -@ {threads} -o {output.bams}; \
                samtools index {output.bams}")
            else:
                shell("hisat2 -p {threads} --summary-file {output.log} -q -x {params.indexName} \
                -1 {input[0]} -2 {input[1]} | samtools view -@ {threads} -Sb -F 4 | samtools sort -@ {threads} -o {output.bams}; \
                samtools index {output.bams}")

elif config["aligner"].upper().find("STAR") >= 0:
    if config["need_indexed"].upper().find("NEED") >= 0:
        rule star_index:
            input:
                fasta = WORKING_DIR + "genome/genome.fa", 
                gtf  = WORKING_DIR + "genome/genome.gtf"
            output:
                directory(WORKING_DIR + 'genome')
            message:
                "indexing genome"
            threads: THREADS
            shell:"""
            STAR --runThreadN {threads} \
            --runMode genomeGenerate \
            --genomeDir {output} \
            --genomeFastaFiles {input.fasta} \
            --sjdbGTFfile {input.gtf} \
            --sjdbOverhang 100
            """

    rule star_mapping:
        input:
            get_trimmed
        output:
            bams = temp(WORKING_DIR + "mapped/{sample}.sorted.bam"),
        log:
            RESULT_DIR + "logs/star/{sample}.log.txt"
        params:
            gtf = WORKING_DIR + 'genome/genome.gtf',
            index = WORKING_DIR + 'genome',
            prefix = WORKING_DIR + "mapped/{sample}.",
            outdir = WORKING_DIR + "mapped",
            sampleName = "{sample}"
        message:
            "mapping reads to genome to bam files."
        threads: THREADS
        run:
            if sample_is_single_end(params.sampleName):
                shell("STAR --runThreadN {threads} --genomeDir {params.index} --outSAMunmapped None --outSAMtype BAM Unsorted \
                --outStd BAM_Unsorted --sjdbGTFfile {params.gtf} --readFilesIn {input[0]} --readFilesCommand zcat \
                --outFileNamePrefix {params.prefix} | samtools sort -@ {threads} -O bam -o {output.bams} 2> {log}")
            else:
                shell("STAR --runThreadN {threads} --genomeDir {params.index} --outSAMunmapped None --outSAMtype BAM Unsorted \
                --outStd BAM_Unsorted --sjdbGTFfile {params.gtf} --readFilesIn {input[0]} {input[1]} --readFilesCommand zcat \
                --outFileNamePrefix {params.prefix} | samtools sort -@ {threads} -O bam -o {output.bams} 2> {log}")

#########################################
# Get table containing the RPKM or FPKM
#########################################

rule stringtie:
    input:
        bams = WORKING_DIR + "mapped/{sample}.sorted.bam"
    output:
        r1 = temp(WORKING_DIR + "stringtie/{sample}/transcript.gtf"),
        r2 = temp(WORKING_DIR + "stringtie/{sample}/gene_abundances.tsv"),
        r3 = temp(WORKING_DIR + "stringtie/{sample}/cov_ref.gtf")
    message:
        "assemble RNA-Seq alignments into potential transcripts."
    threads: THREADS
    params:
        gtf = WORKING_DIR + "genome/genome.gtf"
    shell:
        "stringtie -p {threads} -G {params.gtf} --rf -e -B -o {output.r1} -A {output.r2} -C {output.r3} --rf {input.bams} 2> {log}"

rule create_PKM_table:
    input:
        WORKING_DIR
#        expand(WORKING_DIR + "stringtie/{sample}/transcript.gtf", sample = SAMPLES)
    output:
        r1 = RESULT_DIR + "gene_FPKM.csv",
        r2 = RESULT_DIR + "transcript_FPKM.csv"
    params:
        dataset = config["merge_PKM"]["organism"],
        outdir = directory(RESULT_DIR),
        trans_anno = "scripts/bmIDs_hg.tsv",
        gene_anno = "scripts/bmIDs_g_hg.tsv"
    message:
        "create gene and transcript FPKM(if single-end reads, RPKM)."
    conda:
        "envs/merge_fpkm.yaml"
    shell:
        "Rscript scripts/merge_RFPKM.r --indir temp/ --outdir {params.outdir} --dataset {params.dataset} --trans {params.trans_anno} --gene {params.gene_anno}"

#########################################
# Get table containing the raw counts
#########################################

rule create_counts_table:
    input:
        bams = expand(WORKING_DIR + "mapped/{sample}.sorted.bam", sample = SAMPLES),
    output:
        WORKING_DIR + "counts_.txt"
    message:
        "create read count talbe"
    threads: THREADS
    params:
        gtf  = WORKING_DIR + "genome/genome.gtf"
    shell:
        "featureCounts -T {threads} -a {params.gtf} -t exon -g gene_id -o {output} {input.bams}"

rule get_rid_of_zero_counts:
    input:
        WORKING_DIR + "counts_.txt",
        expand(RESULT_DIR + "fastqc/{sample}_fastqc.html", sample=SAMPLES)
    output:
        RESULT_DIR + "counts.txt"
    message:
        "Delete rows with all zeros"
    params:
        config["organism"].upper(),
        WORKING_DIR + "mapped/"
    script:
        "scripts/postProcess.py"

rule qc_table_maker:
    input:
        RESULT_DIR + "logs/fastp/",
        expand(RESULT_DIR + "logs/fastp/{sample}.log.txt", sample = SAMPLES)
    output:
        RESULT_DIR + "fastp_QC_table.tsv"
    message:
        "Generate fastp QC table through fastp QC reports"
    script:
        "scripts/QC_table_maker.py"

#########################################
# Report for all results
#########################################
rule multiqc:
    input:
        expand(WORKING_DIR + "mapped/{sample}.sorted.bam", sample=SAMPLES),
        RESULT_DIR + "counts.txt"
    output:
        RESULT_DIR + "multiqc/multiqc_report.html"
    params:
        data_dir = [WORKING_DIR, RESULT_DIR],
        res_dir = RESULT_DIR + "multiqc/"
    log:
        RESULT_DIR + "logs/multiqc.log"
    shell:
        "multiqc -f -p {params.data_dir} -o {params.res_dir}"

#########################################
# Gene enrichment
#########################################
rule enrichment:
    input:
        countFile = RESULT_DIR + "counts.txt",
        metadata = config["units"]
    params:
        output_dir = RESULT_DIR + "visualization/",
        heatmap_pval = config["clustering_parmas"]["heatmap"]["pval"],
        heatmapTopGenes = config["clustering_parmas"]["heatmap"]["top_genes"],
        heatmapColor = config["clustering_parmas"]["heatmap"]["color"],
        gsea_pval = config["gsea_params"]["pval_cutoff"],
        gsea_fdr = config["gsea_params"]["fdr_cutoff"]
    shell:"""
    Rscript scripts/clusteringNenrichment_cnt.r --count {input.countFile} --metadata {input.metadata} --outdir {params.output_dir} \
    --fdrval {params.heatmap_pval} --ntopgene {params.heatmapTopGenes} --hmapcolor {params.heatmapColor} \
    --gseafdr {params.gsea_fdr} --gseapval {params.gsea_pval}
    """
