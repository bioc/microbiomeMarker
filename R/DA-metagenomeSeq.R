# We recommend fitFeatureModel over fitZig. MRcoefs, MRtable and MRfulltable
# are useful summary tables of the model outputs. We currently recommend using
# the zero-inflated log-normal model as implemented in fitFeatureModel.
#
# https://github.com/biocore/qiime/blob/master/qiime/support_files/R/fitZIG.r
# https://github.com/xia-lab/MicrobiomeAnalystR/blob/master/R/general_anal.R#L505
# https://support.bioconductor.org/p/78230/

# Difference between fitFeatureModel and fitZIG in metagenomeSeq, https://support.bioconductor.org/p/94138/.
#
# fitFeatureModel doesn't seem to allow for multiple comparisons.

#' metagenomeSeq differential analysis
#'
#' Differential expression analysis based on the Zero-inflated Log-Normal
#' mixture model or Zero-inflated Gaussian mixture model using metagenomeSeq.
#'
#' @param ps  ps a [`phyloseq::phyloseq-class`] object.
#' @param group_var  character, the variable to set the group, must be one of
#'   the var of the sample metadata.
#' @param taxa_rank character to specify taxonomic rank to perform
#'   differential analysis on. Should be one of `phyloseq::rank_names(phyloseq)`,
#'   or "all" means to summarize the taxa by the top taxa ranks
#'   (`summarize_taxa(ps, level = rank_names(ps)[1])`), or "none" means perform
#'   differential analysis on the original taxa (`taxa_names(phyloseq)`, e.g.,
#'   OTU or ASV).
#' @param contrast a two length vector,  The order determines the direction of
#'   fold change, the first element is the numerator for the fold change, and
#'   the second element is used as baseline (denominator for fold change), this
#'   parameter only for two groups comparison.
#' @param transform character, the methods used to transform the microbial
#'   abundance. See [`transform_abundances()`] for more details. The
#'   options include:
#'   * "identity", return the original data without any transformation (default).
#'   * "log10", the transformation is `log10(object)`, and if the data contains
#'     zeros the transformation is `log10(1 + object)`.
#'   * "log10p", the transformation is `log10(1 + object)`.
#' @param norm the methods used to normalize the microbial abundance data. See
#'   [`normalize()`] for more details.
#'   Options include:
#'   * "none": do not normalize.
#'   * "rarefy": random subsampling counts to the smallest library size in the
#'     data set.
#'   * "TSS": total sum scaling, also referred to as "relative abundance", the
#'     abundances were normalized by dividing the corresponding sample library
#'     size.
#'   * "TMM": trimmed mean of m-values. First, a sample is chosen as reference.
#'     The scaling factor is then derived using a weighted trimmed mean over the
#'     differences of the log-transformed gene-count fold-change between the
#'     sample and the reference.
#'   * "RLE", relative log expression, RLE uses a pseudo-reference calculated
#'     using the geometric mean of the gene-specific abundances over all
#'     samples. The scaling factors are then calculated as the median of the
#'     gene counts ratios between the samples and the reference.
#'   * "CSS": cumulative sum scaling, calculates scaling factors as the
#'     cumulative sum of gene abundances up to a data-derived threshold.
#'   * "CLR": centered log-ratio normalization.
#'   * "CPM": pre-sample normalization of the sum of the values to 1e+06.
#' @param norm_para arguments passed to specific normalization methods.
#' @param method character, which model used for differential analysis,
#'   "ZILN" (Zero-inflated Log-Normal mixture model)" or "ZIG" (Zero-inflated
#'    Gaussian mixture model). And the zero-inflated log-normal model is
#'    preferred due to the high sensitivity and low FDR.
#' @param p_adjust method for multiple test correction, default `none`,
#' for more details see [stats::p.adjust].
#' @param pvalue_cutoff numeric, p value cutoff, default 0.05
#' @param ... extra arguments passed to the model. more details see
#'   [`metagenomeSeq::fitFeatureModel()`] and [`metagenomeSeq::fitZig()`],
#'   e.g. `control` (can be setted using [`metagenomeSeq::zigControl()`]) for
#'   [`metagenomeSeq::fitZig()`].
#'
#' @details
#' metagnomeSeq provides two differential analysis methods, zero-inflated
#' log-normal mixture model (implemented in
#' [`metagenomeSeq::fitFeatureModel()`]) and zero-inflated Gaussian mixture
#' model (implemented in [`metagenomeSeq::fitZig()`]). We recommend
#' fitFeatureModel over fitZig due to high sensitivity and low FDR. Both
#' [`metagenomeSeq::fitFeatureModel()`] and [`metagenomeSeq::fitZig()`] require
#' the abundance profiles before normalization.
#'
#' For [`metagenomeSeq::fitZig()`], the output column is the coefficient of
#' interest, and logFC column in the output of
#' [`metagenomeSeq::fitFeatureModel()`] is anologous to coefficient. Thus,
#' logFC is really just the estimate the coefficient of interest in
#' [`metagenomeSeq::fitFeatureModel()`]. For more details see
#' these question [Difference between fitFeatureModel and fitZIG in metagenomeSeq](https://support.bioconductor.org/p/94138/).
#'
#' Of note, [`metagenomeSeq::fitFeatureModel()`] ae not allows for multiple
#' groups comparison.
#'
#' @return  a [`microbiomeMarker-class`] object.
#' @export
#' @author Yang Cao
#' @importFrom stats model.matrix
#' @importFrom metagenomeSeq normFactors<- MRcounts
#' @importFrom Biobase pData<- pData
#' @references
#' Paulson, Joseph N., et al. "Differential abundance analysis for microbial
#' marker-gene surveys." Nature methods 10.12 (2013): 1200-1202.
run_metagenomeseq <- function(ps,
                              group_var,
                              contrast,
                              taxa_rank = "all",
                              transform = c("identity", "log10", "log10p"),
                              norm = "CSS",
                              norm_para = list(),
                              method = c("ZILN", "ZIG"),
                              p_adjust = c("none", "fdr", "bonferroni", "holm",
                                           "hochberg", "hommel", "BH", "BY"),
                              pvalue_cutoff = 0.05,
                              ...) {
  transform <- match.arg(transform, c("identity", "log10", "log10p"))
  method <- match.arg(method, c("ZILN", "ZIG"))
  # test_fun <- ifelse(method == "ZILN",
  #   metagenomeSeq::fitFeatureModel,
  #   metagenomeSeq::fitZig
  # )

  p_adjust <- match.arg(
    p_adjust,
    c("none", "fdr", "bonferroni", "holm",
      "hochberg", "hommel", "BH", "BY")
  )

  # The levels must by syntactically valid names in R, makeContrast
  if (!missing(contrast)) contrast <- make.names(contrast)

  groups <- sample_data(ps)[[group_var]]
  groups <- factor(groups)
  # The levels must by syntactically valid names in R, makeContrast
  levels(groups) <- make.names(levels(groups))
  n_lvl <- length(levels(groups))

  if (n_lvl > 2 && method == "ZILN") {
    stop(
      "ZILN method do not allows for multiple groups comparison.",
      call. = FALSE
    )
  }

  if (missing(contrast)) {
    if (n_lvl == 2) {
      stop("`contrast` is required for two groups comparison.", call. = FALSE)
    }

    if (method == "ZILN")
    stop(
      "ZILN method do not allows for multiple groups comparison.",
      call. = FALSE
    )
  }

  if (!missing(contrast)) {
    if (n_lvl == 2) {
      levels(groups) <- rev(contrast)
    } else {
      contrast_new <- limma::makeContrasts(
        paste(contrast[1], "-", contrast[2]),
        levels = levels(groups)
      )
      # add var scalingFactor
      old_contrast_nms <- row.names(contrast_new)
      contrast_new <- rbind(contrast_new, rep(0, ncol(contrast_new)))
      row.names(contrast_new) <- c(old_contrast_nms, "scalingFactor")
    }
  } else {
    if (n_lvl < 3) {
      stop("`contrast` is required for two groups comparions.")
    }
    contrast_new <- create_contrast(groups)
    # add var scalingFactor
    old_contrast_nms <- row.names(contrast_new)
    contrast_new <- rbind(contrast_new, rep(0, ncol(contrast_new)))
    row.names(contrast_new) <- c(old_contrast_nms, "scalingFactor")
  }


  # preprocess phyloseq object
  ps <- preprocess_ps(ps)
  ps <- transform_abundances(ps, transform = transform)

  # normalization, write a function here
  # fitZig fitFeatureModel
  norm_para <- c(norm_para, method = norm, object = list(ps))
  ps_normed <- do.call(normalize, norm_para)

  # summarize data
  # ps_summarized <- summarize_taxa(ps_normed)
  # check taxa_rank
  check_taxa_rank(ps, taxa_rank)
  if (taxa_rank == "all") {
    ps_summarized <- summarize_taxa(ps_normed)
  } else if (taxa_rank =="none") {
    ps_summarized <- extract_rank(ps_normed, taxa_rank)
  } else {
    ps_summarized <-aggregate_taxa(ps_normed, taxa_rank) %>%
      extract_rank(taxa_rank)
  }
  mgs_summarized <- phyloseq2metagenomeSeq(ps_summarized)

  # extract norm factors and set the norm factors of MRexperiment
  nf <- get_norm_factors(ps_normed)
  if (!is.null(nf)) {
    pData(mgs_summarized@expSummary$expSummary)$normFactors <- nf
  } else {
    # for TSS, CRL and rarefy: normalized the feature table using CSS method
    ct <- metagenomeSeq::MRcounts(mgs_summarized, norm = FALSE)
    fun_p <- select_quantile_func(ct)
    mgs_summarized <- metagenomeSeq::cumNorm(
      mgs_summarized,
      p = fun_p(mgs_summarized)
    )
  }

  sl <- ifelse("sl" %in% names(norm_para), norm_para[["sl"]], 1000)
  counts_normalized <- metagenomeSeq::MRcounts(
    mgs_summarized,
    norm = TRUE,
    sl = sl
  )

  mod <- model.matrix(~groups)
  colnames(mod) <- levels(groups)


  if (n_lvl == 2) {
    if (method == "ZILN") {
      tryCatch(
        fit <- metagenomeSeq::fitFeatureModel(mgs_summarized, mod, ...),
        error = function(e) {
           paste0(
             "fitFeatureModel model failed to fit to your data! ",
            "Consider fitZig model or further filtering your dataset!"
          )
        }
      )
    } else {
      tryCatch(
        fit <- metagenomeSeq::fitZig(mgs_summarized, mod, ...),
        error = function(e) {
          paste0(
            "fitZig model failed to fit to your data! ",
            "Consider fitFeatureModel model or further filtering your dataset!"
          )
        }
      )
    }

    # metagenomeSeq vignette: We recommend the user remove features based on the
    # number of estimated effective samples, please see
    # calculateEffectiveSamples.We recommend removing features with less than
    # the average number of effective samples in all features. In essence,
    # setting eff = .5 when using MRcoefs, MRfulltable, or MRtable.
    res <- metagenomeSeq::MRcoefs(
      fit,
      number = ntaxa(ps_summarized),
      adjustMethod = p_adjust,
      group = 3,
      eff = 0.5
    )
    res <- dplyr::rename(res, pvalue = .data$pvalues, padj = .data$adjPvalues)

    # For fitZig, the output var is the coefficient of interest (effect size),
    # For fitFeaturemodel, logFC is anologous to coefficient of fitZig
    # (as logFC is really just the estimate the coefficient of interest).
    ef_var <- ifelse(method == "ZILN", "logFC", contrast[1])
    res$enrich_group <- ifelse(res[[ef_var]] > 0, contrast[1], contrast[2])

  } else {
    fit <- metagenomeSeq::fitZig(mgs_summarized, mod, ...)
    zigfit <- slot(fit, "fit")
    new_fit <- limma::contrasts.fit(zigfit, contrasts = contrast_new)
    new_fit <- limma::eBayes(new_fit)
    res <- limma::topTable(
      new_fit,
      number = Inf,
      adjust.method = p_adjust,
      p.value = pvalue_cutoff
    )
    res <- dplyr::rename(res, pvalue = .data$P.Value, padj = .data$adj.P.Val)
    # enrich_group
    if (missing(contrast)) { # multiple groups comparison
      n_pairs <- ncol(contrast_new)
      contrasts_pairs <- colnames(contrast_new)
      names(res)[1:n_pairs] <- contrasts_pairs
      group_pairs <- strsplit(contrasts_pairs, "-")
      logFCs <- res[, 1:n_pairs]
      enrich_group <- apply(
        logFCs,
        1,
        get_mgs_enrich_group,
        group_pairs = group_pairs
      )
    } else {
      enrich_group <- ifelse(res$logFC > 0, contrast[1], contrast[2])
    }
    ef_var <- ifelse(missing(contrast), "F", "logFC")
    res$enrich_group <- enrich_group
  }


  res_filtered <- res[res$padj < pvalue_cutoff & !is.na(res$padj), ]

  # write a function
  if (nrow(res_filtered) == 0) {
    warning("No significant features were found, return all the features")
    sig_feature <- cbind(feature = row.names(res), res)
  } else {
    sig_feature <- cbind(feature = row.names(res_filtered), res_filtered)
  }

  # only keep five variables: feature, enrich_group, effect_size (e.g. logFC),
  # pvalue, and padj
  sig_feature <- sig_feature[, c("feature", "enrich_group",
                                 ef_var, "pvalue", "padj")]
  row.names(sig_feature) <- paste0("marker", seq_len(nrow(sig_feature)))

  # rename the ef
  names(sig_feature)[3] <- ifelse(
    ef_var %in% c("logFC", "F"),
    paste0("ef_", ef_var),
    paste0("ef_", "coef")
  )

  marker <- microbiomeMarker(
    marker_table = marker_table(sig_feature),
    norm_method = get_norm_method(norm),
    diff_method = paste0("metagenomeSeq: ", method),
    otu_table = otu_table(counts_normalized, taxa_are_rows = TRUE),
    sam_data = sample_data(ps_normed),
    # tax_table = tax_table(ps_summarized),
    tax_table = tax_table(ps_summarized)
  )

  marker
}



# This function is modified from `phyloseq::phyloseq_to_metagenomeSeq()`,
# There two changes: 1) do not coerce count data to vanilla matrix of integers;
# 2) do not normalize the count.
#
#
#' Convert phyloseq data to MetagenomeSeq `MRexperiment` object
#'
#' The phyloseq data is converted to the relevant
#' [`metagenomeSeq::MRexperiment-class`] object, which can then be tested in
#' the zero-inflated mixture model framework in the metagenomeSeq package.
#'
#' @param ps [`phyloseq::phyloseq-class`] object for
#'   `phyloseq2metagenomeSeq()`, or [`phyloseq::otu_table-class`] object
#'   for `otu_table2metagenomeseq()`.
#' @param ... optional, additional named arguments passed  to
#'   [`metagenomeSeq::newMRexperiment()`]. Most users will not need to pass
#'   any additional arguments here.
#' @return A [`metagenomeSeq::MRexperiment-class`] object.
#' @seealso [`metagenomeSeq::fitTimeSeries()`],[`metagenomeSeq::fitLogNormal()`],
#'   [`metagenomeSeq::fitZig()`],[`metagenomeSeq::MRtable()`],
#'   [`metagenomeSeq::MRfulltable()`]
#' @export
#' @importFrom Biobase AnnotatedDataFrame
#' @importMethodsFrom phyloseq t
phyloseq2metagenomeSeq <- function(ps, ...) {
  # Enforce orientation. Samples are columns
  if (!taxa_are_rows(ps) ) {
    ps <- t(ps)
  }

  count <- as(otu_table(ps), "matrix")
  # Create sample annotation if possible
  if (!is.null(sample_data(ps, FALSE))) {
    adf <- AnnotatedDataFrame(data.frame(sample_data(ps)))
  } else {
    adf <- NULL
  }

  # Create taxa annotation if possible
  if (!is.null(tax_table(ps, FALSE))) {
    tdf <- AnnotatedDataFrame(
      data.frame(
        OTUname = taxa_names(ps),
        data.frame(tax_table(ps)),
        row.names = taxa_names(ps)
      )
    )
  } else {
    tdf <- AnnotatedDataFrame(
      data.frame(
        OTUname = taxa_names(ps),
        row.names = taxa_names(ps)
      )
    )
  }

  # setting the norm factor, or the fitzig or
  # nf <- sample_data(ps)[["metagenomeSeq_norm_factor"]]

  # Create MRexperiment
  mr_obj = metagenomeSeq::newMRexperiment(
    counts = count,
    phenoData = adf,
    featureData = tdf,
    ...
  )

  mr_obj
}


#' @rdname phyloseq2metagenomeSeq
#' @export
otu_table2metagenomeSeq <- function(ps, ...) {
  stopifnot(inherits(ps, "otu_table"))
  # create a sample data with only one var "sample": sam1, sam2
  sdf <- sample_data(data.frame(sample = paste0("sam", 1:ncol(ps))))
  row.names(sdf) <- colnames(ps)

  ps <- phyloseq(
    ps,
    sdf
  )
  mgs <- phyloseq2metagenomeSeq(ps)

  mgs
}


# get enrich group of a feature for multiple groups comparison
# group_pairs and logFC_pairs are the same length
get_mgs_enrich_group <- function(group_pairs, logFC_pairs) {
  all_groups <- unique(unlist(group_pairs))
  for (i in seq_along(group_pairs)) {
    group_low <- ifelse(
      logFC_pairs[i] > 0,
      group_pairs[[i]][2],
      group_pairs[[i]][1]
    )
    all_groups <- setdiff(all_groups, group_low)
  }

  all_groups
}