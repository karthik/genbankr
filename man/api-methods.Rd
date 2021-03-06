% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/api-methods.R
\docType{methods}
\name{cds,GenBankRecord-method}
\alias{cds,GenBankRecord-method}
\alias{cdsBy,GenBankRecord}
\alias{cdsBy,GenBankRecord-method}
\alias{exons,GenBankRecord-method}
\alias{exonsBy,GenBankRecord}
\alias{exonsBy,GenBankRecord-method}
\alias{genes,GenBankRecord-method}
\alias{getSeq,GBAccession-method}
\alias{getSeq,GenBankFile-method}
\alias{getSeq,GenBankRecord-method}
\alias{isCircular,GenBankRecord}
\alias{isCircular,GenBankRecord-method}
\alias{seqinfo,GenBankRecord}
\alias{seqinfo,GenBankRecord-method}
\alias{transcripts,GenBankRecord-method}
\title{Annotation extraction api}
\usage{
\S4method{cds}{GenBankRecord}(x)

\S4method{exons}{GenBankRecord}(x)

\S4method{genes}{GenBankRecord}(x)

\S4method{transcripts}{GenBankRecord}(x)

\S4method{getSeq}{GenBankRecord}(x, ...)

\S4method{getSeq}{GenBankFile}(x, ...)

\S4method{getSeq}{GBAccession}(x, ...)

\S4method{cdsBy}{GenBankRecord}(x, by = c("tx", "gene"))

\S4method{exonsBy}{GenBankRecord}(x, by = c("tx", "gene"))

\S4method{isCircular}{GenBankRecord}(x)

\S4method{seqinfo}{GenBankRecord}(x)
}
\arguments{
\item{x}{The object containing the annotations}

\item{...}{unused.}

\item{by}{character. Factor to group the resulting GRanges by.}
}
\value{
The expected types, \code{GenomicRanges} for most functions,
a \code{DNAStrimgSet} for \code{getSeq}
}
\description{
Accessor functions shared with the larger Bioconductor
ecosystem.
}
\examples{
gb = readGenBank(system.file("sample.gbk", package="genbankr"))
cds(gb)
exons(gb)
genes(gb)
}

