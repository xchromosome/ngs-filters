#!/usr/bin/env Rscript

##########################################################################################
# MSKCC CMO
# Annotate DAC blacklisted regions obtained from:
# https://www.encodeproject.org/annotations/ENCSR636HFF/
##########################################################################################

annotate_maf <- function(maf, blacklist, rmsk) {

    setkey(blacklist, Chromosome, Start_Position, End_Position)
    setkey(rmsk, Chromosome, Start_Position, End_Position)

    blacklist_overlap <- foverlaps(maf[, .(Chromosome, Start_Position, End_Position)],
                                   blacklist,
                                   type = "within",
                                   mult = "first")

    rmsk_overlap <- foverlaps(maf[, .(Chromosome, Start_Position, End_Position)],
                              rmsk,
                              type = "within",
                              mult = "first")

    if (!('FILTER' %in% names(maf))) maf$FILTER = '.'
    maf.annotated <- maf[, blacklist_region := blacklist_overlap$Info]
    maf.annotated <- maf[, repeat_masker := rmsk_overlap$Info]
    maf.annotated <- maf[, FILTER := ifelse(!is.na(blacklist_region), ifelse((FILTER == '' | FILTER == '.' | FILTER == 'PASS' | is.na(FILTER)), 'blacklist_region', paste0(FILTER, ';blacklist_region')), FILTER)]
    maf.annotated <- maf[, FILTER := ifelse(!is.na(repeat_masker), ifelse((FILTER == '' | FILTER == '.' | FILTER == 'PASS' | is.na(FILTER)), 'repeat_masker', paste0(FILTER, ';repeat_masker')), FILTER)]
    return(maf.annotated)
}

if (!interactive()) {

    pkgs = c('data.table', 'argparse', 'kimisc')
    junk <- lapply(pkgs, function(p){suppressPackageStartupMessages(require(p, character.only = T))})
    rm(junk)
  
    args = commandArgs(trailingOnly = FALSE)
    path = dirname(thisfile())
    #path = dirname(stringr::str_replace((args[4]), '--file=', ''))
  
    parser=ArgumentParser()
    parser$add_argument('-m', '--maf', type='character', help='SOMATIC_FACETS.vep.maf file', default = 'stdin')
    parser$add_argument('-b', '--blacklist', type='character', help='DAC Blacklisted Regions',
                        default = paste0(path, '/data/', 'wgEncodeDacMapabilityConsensusExcludable.bed'))
    parser$add_argument('-r', '--repeatmasker', type='character', help='Modified RepeatMasker file',
                        default = paste0(path, '/data/', 'rmsk_mod.bed'))
    parser$add_argument('-o', '--outfile', type='character', help='Output file', default = 'stdout')
    args=parser$parse_args()
  
    if (args$maf == 'stdin') {
        maf = suppressWarnings(fread('cat /dev/stdin',  colClasses=c(Chromosome="character"), showProgress = F))
    }
    else {
        maf <- suppressWarnings(fread(args$maf, colClasses=c(Chromosome="character"), showProgress = F))
    }
    blacklist <- suppressWarnings(fread(args$blacklist, showProgress = F))
    rmsk <- suppressWarnings(fread(args$repeatmasker, showProgress = F))
    outfile <- args$outfile
  
    blacklist[, c('V5', 'V6') := NULL]
    setnames(blacklist, c("Chromosome", "Start_Position", "End_Position", "Info"))
    blacklist[, Chromosome := gsub("chr", "", Chromosome)]
    setnames(rmsk, c("Chromosome", "Start_Position", "End_Position", "Info"))
    rmsk[, Chromosome := gsub("chr", "", Chromosome)]
  
    maf.out <- annotate_maf(maf, blacklist, rmsk)
    maf.out$blacklist_region <- NULL
    maf.out$repeat_masker <- NULL
    if (outfile == 'stdout') {
        write.table(maf.out, stdout(), na="", sep = "\t", col.names = T, row.names = F, quote = F)
    }
    else {
        write.table(maf.out, outfile, na="", sep = "\t", col.names = T, row.names = F, quote = F)
    }
}
