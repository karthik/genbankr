## check if <1 means circular passing across boundary
## check how insertion before first element is specified


##' @import IRanges
##' @import GenomicRanges
##' @import GenomicFeatures
##' @import methods
##' @import Biostrings
NULL


##' @title Read a GenBank File
##' @description Read a GenBank file from a local file, or retrieve
##' and read one based on an accession number. See Details for exact
##' behavior.
##' 
##' @param file character or GBAccession. The path to the file, or a GBAccession object containing Nuccore versioned accession numbers. Ignored if \code{text} is specified.
##' @param text character. The text of the file. Defaults to text within \code{file}
##' @param partial logical. If TRUE, features with non-exact boundaries will
##' be included. Otherwise, non-exact features are excluded, with a warning
##' if \code{partial} is \code{NA} (the default).
##' @param ret.seq logical. Should an object containing the raw ORIGIN sequence be
##' created and returned. Defaults to \code{TRUE}
##' @param verbose logical. Should informative messages be printed to the
##' console as the file is processed. Defaults to \code{FALSE}.
##'
##' @details If a a\code{GBAccession} object is passed to \code{file}, the
##' rentrez package is used to attempt to fetch full GenBank records for all
##' ids in the 
##'
##' 
##' 
##' Often times, GenBank files don't contain exhaustive annotations.
##' For example, files including CDS annotations often do not have separate
##' transcript features.  Furthermore, chromosomes are not always named,
##' particularly in organisms that have only one. The details of how genbankr
##' handles such cases are as follows:
##' 
##' In files where CDSs are annotated but individual exons are not, 'approximate
##' exons' are defined as the individual contiguous elements within each CDS.
##' Currently, no mixing of approximate and explicitly annotated exons is
##' performed, even in cases where, e.g., exons are not annotated for some
##' genes with CDS annotations.
##' 
##' In files where transcripts are not present, 'approximate transcripts'
##' defined by the ranges spanned by groups of exons are used.  Currently, we do
##' not support generating approximate transcripts from CDSs in files that
##' contain actual transcript annotations, even if those annotations do not
##' cover all genes with CDS/exon annotations.
##'
##'
##' Features  (gene, cds, variant, etc) are assumed to be contained within the
##' most recent previous source feature (chromosome/physical piece of DNA).
##' Chromosome name for source features (seqnames in the resulting
##' \code{GRanges}/\code{VRanges} is determined  as follows:
##' \enumerate{
##' \item{The 'chromosome' attribute, as is (e.g., "chr1");}
##' \item{the 'strain' attribute, combined with auto-generated count (e.g.,
##' "VR1814:1");}
##' \item{the 'organism' attribute, combined with auto-generated count (e.g.
##' "Human herpesvirus 5:1".}
##' }
##'
##' In files where no origin sequence is present, importing varation
##' features is not currently supported, as there is no easy/
##' self-contained way of determining the reference in those
##' situations and the features themselves list only alt. If
##' variation features are present in a file without origin
##' sequence, those features are ignored with a warning.
##'
##' Currently some information about from the header of a GenBank file,
##' primarily reference and author based information, is not captured and
##' returned. Please contact the maintainer if you have a direct use-case for
##' this type of information.
##'
##' @note We have endeavored to make this parser as effcient as easily possible.
##' On our local machines, a 19MB genbank file takes 2-3 minutes to be parsed.
##' That said, this function is not tested and likely not suitable for
##' processing extremely large genbank files. 
##' 
##' @return A \code{GenBankAnnot} or \code{GenBankFull} object containing (most,
##' see detaisl) of the information within \code{file}/\code{text} Or a list of
##' \code{GenBankAnnot}/\code{GenBankFull} objects in cases where a
##' \code{GBAccession} vector with more than one ID in it is passed to \code{file}
##' @examples
##' gb = readGenBank(system.file("sample.gbk", package="genbankr"))
##' @export
readGenBank = function(file, text = readLines(file), partial = NA,
                       ret.seq = TRUE, verbose = FALSE) {

    if(missing(text) && is(file, "GBAccession"))
        text = .getGBfromNuccore(file)
    if(is(text, "list"))
        return(lapply(text, function(txt) readGenBank(text = txt, partial = partial, ret.seq= ret.seq, verbose = verbose)))
    prsed = parseGenBank(text = text, partial = partial, verbose = verbose)
    if(!ret.seq)
        ret = make_gbannot(rawgbk = prsed, verbose = verbose)
    else
        ret = make_gbfull(rawgbk = prsed, verbose = verbose)
    ret
}

.getGBfromNuccore = function(id) {
    if(!requireNamespace("rentrez"))
        stop("The rentrez package is required to retreive GenBank annotations from NCBI")
    foundids = lapply(id, function(txt) {
        ids = rentrez::entrez_search("nuccore", paste0(txt, "[ACCN]"))$ids
        ids
        })
    found = sapply(foundids, function(x) length(x) ==1)
    if(!all(found)) {
        warning("Unable to find entries for id(s):", paste(id[!found], collapse = " "))
        foundids = unlist(foundids[found])
    }
    if(length(foundids) == 0)
        stop("None of the specified id(s) were found in the nuccore database")
    
    res = rentrez::entrez_fetch("nuccore", foundids, rettype="gbwithparts", retmode="text")

    lines = fastwriteread(res)
    if(length(foundids) > 1) {
        fac = cumsum(grepl("^//$", lines))
        ret = split(lines, fac)
        names(ret) = id[found]
    } else
        ret = lines
    ret
}


prime_field_re = "^[[:upper:]]+[[:space:]]+"
sec_field_re = "^( {5}|\\t)[[:alnum:]'_]+[[:space:]]+(complement|join|order|[[:digit:]<,])"

strip_fieldname = function(lines) gsub("^[[:space:]]*[[:upper:]]*[[:space:]]+", "", lines)


## Functions to read in the fields of a GenBank file


readLocus = function(line) {
    ## missing strip fieldname?
    spl = strsplit(line, "[\\t]+", line)[[1]]
    spl
}

readDefinition = function(lines) {
    paste(strip_fieldname(lines), collapse = " ")
}

readAccession = function(line)  strip_fieldname(line)

readVersions = function(line) {
    txt = strip_fieldname(line)
    spl = strsplit(txt, "[[:space:]]+")[[1]]
    c(accession.version = spl[1], GenInfoID = gsub("GI:", "", spl[2]))
}

readKeywords = function(lines) {
    txt = strip_fieldname(lines)
    txt = paste(txt, collapse = " ")
    if(identical(txt, "."))
        txt = NA_character_
    txt
}

readSource = function(lines) {
    secfieldinds = grep(sec_field_re, lines)
    src = strip_fieldname(lines[1])
    lines = lines[-1] #consume SOURCE line
    org = strip_fieldname(lines[1])
    lines = lines[-1] # consume ORGANISM line
    lineage = strsplit(paste(lines, collapse = " "), split  = "; ")[[1]]
    list(source= src, organism = org, lineage = lineage)
}


chk_outer_complement = function(str) grepl("[^(]*complement\\(", str)
strip_outer_operator = function(str, op = "complement") {
    regex = paste0("[^(]*", op, "\\((.*)\\)")
    
    gsub(regex,"\\1", str)
}

.do_join_silliness = function(str, chr, ats, partial = NA, strand = NA) {
    
                                        #    if(grepl("^join", str))
    sstr = substr(str, 1, 1)
    if(sstr == "j") ##join
        str = strip_outer_operator(str, "join")
    else if(sstr == "o") ## order (grepl("^order", str))
        str = strip_outer_operator(str, "order")
    spl = strsplit(str, ",", fixed=TRUE)[[1]]
    grs = lapply(spl, make_feat_gr, chr = chr, ats = ats,
                 partial = partial, strand = strand)
    ##    do.call(rbind.data.frame, grs)
    .simple_rbind_dataframe(grs)
}


make_feat_gr = function(str, chr, ats, partial = NA, strand = NA) {

    if(is.na(strand) && chk_outer_complement(str)) {
        strand = "-"
        str = strip_outer_operator(str)
    } 
    
    
    ##    if (grepl("(join|order)", str))
    ##    if(grepl("join", fixed=TRUE, str) | grepl("order", str, fixed=TRUE))
    sbstr = substr(str, 1, 4)
    if(sbstr == "join" || sbstr == "orde")
        return(.do_join_silliness(str = str, chr = chr,
                                  ats = ats, partial = partial,
                                  strand = strand))
    haslt = grepl("<", str, fixed=TRUE) || grepl(">", str, fixed=TRUE)
    
    
    ## control with option. Default to exclude those ranges entirely.
    ##    if( (haslt || hasgt ) && (is.na(partial) || !partial) ){
    if( haslt  && (is.na(partial) || !partial) ){
        if(is.na(partial))
            warning("Incomplete feature annotation detected. ",
                    "Omitting feature at ", str)
        return(GRanges(character(), IRanges(numeric(), numeric())))
    }
    
    ## format is 123, 123..789, or 123^124
    spl = strsplit(str, "[.^]{1,2}")[[1]]
    start = as.integer(gsub("<*([[:digit:]]+).*", "\\1", spl[1]))
    if(length(spl) == 1)
        end = start
    else
        end = as.integer(gsub(">*([[:digit:]]+).*", "\\1", spl[2]))
    if(grepl("^", str, fixed=TRUE )) {
        end = end - 1
        ats$loctype = "insert"
    } else
        ats$loctype = "normal"
    
    if(is.na(strand))
        strand = "+"

    gr = cheap_unsafe_data.frame(lst = c(seqnames = chr, start = start, end = end, strand = strand, ats))
    gr
}

read_feat_attr = function(line) {
    num =  grepl('=[[:digit:]]+(\\.[[:digit:]]+){0,1}$', line)
    #val = gsub('[[:space:]]*/[^=]+="{0,1}([^"]*)"{0,1}', "\\1", line)
    val = gsub('[[:space:]]*/[^=]+($|="{0,1}([^"]*)"{0,1})', "\\2", line)
    mapply(function(val, num) {
        if(nchar(val)==0)
            TRUE
        else if(num)
            as.numeric(val)
        else
            val
    }, val = val, num = num, SIMPLIFY=FALSE)
}


## XXX is the leading * safe here? whitespace is getting clobbered by line
##combination below I think it's ok
strip_feat_type = function(ln) gsub("^[[:space:]]*[[:alnum:]_']+[[:space:]]+((complement\\(|join\\(|order\\(|[[:digit:]<]+).*)", "\\1", ln)

readFeatures = function(lines, partial = NA, verbose = FALSE,
                        source.only = FALSE) {
    if(substr(lines[1], 1, 8) == "FEATURES")
        lines = lines[-1] ## consume FEATURES line
    fttypelins = grepl(sec_field_re, lines)
    featfactor  = cumsum(fttypelins)
    
    if(source.only) {
        srcfeats = which(substr(lines[fttypelins], 6, 11) == "source")
        keepinds = featfactor %in% srcfeats
        lines = lines[keepinds]
        featfactor = featfactor[keepinds]
    }
    
    ##scope bullshittery
    chr = "unk"
    
    totsources = length(grep("[[:space:]]+source[[:space:]]+[<[:digit:]]", lines[which(fttypelins)]))
    numsources = 0
    everhadchr = FALSE
    
    do_readfeat = function(lines, partial = NA) {
        
        ## before collapse so the leading space is still there
        type = gsub("[[:space:]]+([[:alnum:]_']+).*", "\\1", lines[1])
        ##feature/location can go across multpiple lines x.x why genbank? whyyyy
        attrstrts = cumsum(grepl("^[[:space:]]+/[^[:space:]]+($|=([[:digit:]]|\"))", lines))
        lines = tapply(lines, attrstrts, function(x) {
            paste(gsub("^[[:space:]]+", "", x), collapse="")
        }, simplify=TRUE)
        
        rawlocstring = lines[1]
        
        rngstr = strip_feat_type(rawlocstring)
        
        ## consume primary feature line
        lines = lines[-1] 
        if(length(lines)) {
            attrs = read_feat_attr(lines)#lapply(lines, read_feat_attr)
            
            names(attrs) = gsub("^[[:space:]]*/([^=]+)($|=[^[:space:]].*$)", "\\1", lines)
            if(type == "source") {
                numsources <<- numsources + 1
                if("chromosome" %in% names(attrs)) {
                    if(numsources > 1 && !everhadchr)
                        stop("This file appears to have some source features which specify chromosome names and others that do not. This is not currently supported. Please contact the maintainer if you need this feature.")    
                    everhadchr <<- TRUE
                    chr <<- attrs$chromosome
                } else if(everhadchr) {
                    stop("This file appears to have some source features which specify chromosome names and others that do not. This is not currently supported. Please contact the maintainer if you need this feature.")
                    ## this assumes that if one source has strain, they all will.
                    ## Good assumption?
                } else if("strain" %in% names(attrs)) {
                    chr <<- if(totsources == 1) attrs$strain else paste(attrs$strain, numsources, sep=":")
                } else {
                    chr <<- if(totsources == 1) attrs$organism else paste(attrs$organism, numsources, sep=":")
                }
            }
        } else {
            attrs = list()
        }
        make_feat_gr(str = rngstr, chr = chr, ats = c(type = type, attrs),
                     partial = partial)
        
    }
    
    if(verbose)
        message(Sys.time(), " Starting feature parsing")
    resgrs = tapply(lines, featfactor, do_readfeat,
                    simplify=FALSE, partial = partial)
    if(verbose)
        message(Sys.time(), " Done feature parsing")
    
    resgrs
    
}

readOrigin = function(lines) {
    ## strip spacing and line numbering
    regex = "([[:space:]]+|[[:digit:]]+|//)"
    
    DNAString(paste(gsub(regex, "", lines[-1]), collapse=""))
}


fastwriteread = function(txtline) {
    f = file()
    on.exit(close(f))
    writeLines(txtline, con = f)
    readLines(f)
    
}



## substr is faster than grep for looking at beginning of strings


##' @title Parse raw genbank file content
##' @description Parse genbank content and return a low-level list object
##' containing each component of the file.
##' @param file character. The file to be parsed. Ignored if \code{text} is
##' specified
##' @param text character. The text to be parsed.
##' @param partial logical. If TRUE, features with non-exact boundaries will
##' be included. Otherwise, non-exact features are excluded, with a warning
##' if \code{partial} is \code{NA} (the default).
##' @param verbose logical. Should informative messages be printed to the
##' console as the file is being processed.
##' @param seq.only logical. Should a fast-path which extracts only the origin
##' sequence be used, rather than processing the entire file. (Defaults to
##' \code{FALSE}
##' @return A list containing the parsed contents of the file, suitable for
##' passing to \code{make_gbannot} or \code{make_gbfull}
##' @note This is a low level function not intended for common end-user use.
##' In nearly all cases, end-users (and most developers) should call
##' \code{readGenBank} or create a \code{GenBankFile} object and call
##' \code{import} instead.
##' @examples
##' prsd = parseGenBank(system.file("sample.gbk", package="genbankr"))
##' @export

parseGenBank = function(file, text = readLines(file),  partial = NA,
                        verbose = FALSE,
                        seq.only = FALSE) {
    bf = proc.time()["elapsed"]
    if(length(text) == 1)
        text = fastwriteread(text)
    
    fldlines = grepl(prime_field_re, text)
    fldfac = cumsum(fldlines)
    fldnames = gsub("^([[:upper:]]+).*", "\\1", text[fldlines])[fldfac]
    
    spl = split(text, fldnames)
    
    resthang = list(FEATURES = readFeatures(spl[["FEATURES"]],
                                            source.only=seq.only),
                    ORIGIN = readOrigin(spl[["ORIGIN"]]))
    if(!seq.only) {
        resthang2 = mapply(function(field, lines, verbose) {
            switch(field,
                   LOCUS = readLocus(lines),
                   DEFINITION = readDefinition(lines),
                   ACCESSION = readAccession(lines),
                   VERSION = readVersions(lines),
                   KEYWORDS = readKeywords(lines),
                   SOURCE = readSource(lines),
                   ## don't read FEATURES or ORIGIN because they are already
                   ## in resthang from above
                   NULL)
        }, lines = spl, field = names(spl), SIMPLIFY=FALSE, verbose = verbose)
        resthang2$FEATURES = resthang2$FEATURES[sapply(resthang2$FEATURES,
                                                       function(x) length(x)>0)]
        resthang2 = resthang2[!names(resthang2) %in% names(resthang)]
        resthang = c(resthang, resthang2)
    }
    ##DNAString to DNAStringSet
    origin = resthang$ORIGIN 
    if(is(origin, "DNAString") && length(origin) > 0) {
        typs = sapply(resthang$FEATURES, function(x) x$type[1])
        srcs = fill_stack_df(resthang$FEATURES[typs == "source"])
        ## dss = DNAStringSet(lapply(GRanges(ranges(srcs), function(x) origin[x])))
        dss = DNAStringSet(lapply(ranges(srcs), function(x) origin[x]))
        names(dss) = sapply(srcs,
                            function(x) as.character(seqnames(x)[1]))
        if(seq.only)
            resthang = dss
        else
            resthang$ORIGIN = dss
    } else if (seq.only) {
        stop("Asked for seq.only from a file with no sequence information")
    }
    af = proc.time()["elapsed"]
    if(verbose)
        message("Done Parsing raw GenBank file text. [ ", af-bf, " seconds ]") 
    resthang

    
}

##866 512 7453

## slightly specialized function to stack granges which may have different
## mcols together, filling with NA_character_ as needed.
## also collapses multiple db_xref notes into single CharacterList column and
## creates an AAStringSet for the translation field


fill_stack_df = function(dflist, cols, fill.logical = TRUE, sqinfo = NULL) {
    if(length(dflist) == 0)
        return(NULL)
    if(length(dflist) > 1) {

        allcols = unique(unlist(lapply(dflist, function(x) names(x))))
        logcols = unique(unlist(lapply(dflist, function(x) names(x)[sapply(x, is.logical)])))
        charcols = setdiff(allcols, logcols)
        dbxr = grep("db_xref", allcols)
        if(length(dbxr) > 1) {
            allcols = c(allcols[-dbxr], "db_xref")
            mult_xref = TRUE
        } else {
            mult_xref = FALSE
        }
        
        if(missing(cols))
            cols = allcols
        
        
        ## filled = lapply(grlist,
        filled = mapply(
            function(x, i) {
            if(mult_xref) {
                loc_dbxr = grep("db_xref", names(x))
                rows = lapply(seq(along = rownames(x)),
                              function(y) unlist(x[y,loc_dbxr]))
                x = x[,-loc_dbxr]
                x$db_xref = I(rows)
            }
        
        

        ## setdiff is not symmetric
            missnm = setdiff(charcols, names(x))
            x[,missnm] = NA_character_
            falsenm = setdiff(logcols, names(x))
            x[,falsenm] = FALSE
            x = x[,cols]
            x$temp_grouping_id = i
            x
        }, x = dflist, i = seq(along = dflist), SIMPLIFY=FALSE)
 #   stk = do.call(rbind, c(filled, deparse.level=0, make.row.names=FALSE))
        stk = .simple_rbind_dataframe(filled, "temp")
    } else {
        stk = dflist[[1]]
    }
    stk[["temp"]] = NULL
    mc = names(stk)[!names(stk) %in% c("seqnames", "start", "end", "strand")]
    if(fill.logical) {
        logcols = which(sapply(stk, is.logical))
        stk[,logcols] = lapply(logcols, function(i) {
            dat = stk[[i]]
            dat[is.na(dat)] = FALSE
            dat
        })
    }
    grstk = GRanges(seqnames = stk$seqnames,
                    ranges = IRanges(start = stk$start, end = stk$end),
                    strand = stk$strand ) ##, mcols = stk[,mc])
    ## this may be slightly slower, but specifying mcols during
    ## creation appends mcols. to all the column names, super annoying.
    mcols(grstk) = stk[,mc]
    if("translation" %in% names(mcols(grstk))) {
        if(anyNA(grstk$translation)) {
            message("Translation product seems to be missing for ",
                    sum(is.na(grstk$translation)),
                    " of ", length(grstk), " ",
                    grstk$type[1], " annotations. Setting to ''")
            grstk$translation[is.na(grstk$translation)] = ""
        }
        grstk$translation = AAStringSet(grstk$translation)
    }

    if(!is.null(sqinfo))
        seqinfo(grstk) = sqinfo
    grstk



}



match_cds_genes = function(cds, genes) {

    ## XXX do we want "equal" here or within?
    hits = findOverlaps(cds, genes, type = "equal")
    cds$gene = NA_character_
    cds$gene[queryHits(hits)] = genes$gene
    if(anyNA(cds$gene)) {
        warning("unable to determine gene for some CDS annotations.",
                " Ignoring these ", sum(is.na(cds$gene)), " segments")
        cds = cds[!is.na(cds$gene)]
    }
    cds
}


make_cdsgr = function(rawcdss, gns, sqinfo) {
  
    ##    rawcdss = sanitize_feats(rawcdss, cds_cols)
    rawcdss = fill_stack_df(rawcdss, sqinfo = sqinfo)
    ## double order gives us something that can be merged directly into what
    ## out of tapply

    havegenelabs = FALSE
    if(is.null(rawcdss$gene) && !is.null(rawcdss$locus_tag)) {
        message("CDS annotations do not have 'gene' label, using 'locus_tag'")
        rawcdss$gene = rawcdss$locus_tag
    }
    if(!is.null(rawcdss$gene) && !anyNA(rawcdss$gene)) {
   
        o = order(order(rawcdss$gene))
        var = "gene"
    } else {
        message("genes not available for all CDS ranges, using internal grouping ids")
        var = "temp_grouping_id"
        o = order(order(rawcdss$temp_grouping_id))
    }
    idnum = unlist(tapply(rawcdss$temp_grouping_id, mcols(rawcdss)[[var]], function(x) as.numeric(factor(x)), simplify=FALSE))[o]
    newid = paste(mcols(rawcdss)[[var]], idnum, sep=".")
    if(var == "temp_grouping_id")
        newid = paste0(ifelse(is.na(mcols(rawcdss)$gene), "unknown_gene_",mcols(rawcdss)$gene),  newid)

    cdss = rawcdss
    cdss$transcript_id = newid
    ## cdsslst = GRangesList(cdssraw)
    ## cdss = unlist(cdsslst)
    cdss$gene_id = cdss$gene
    cdss$gene = NULL
    cdss$temp_grouping_id = NULL
    cdss
}


make_txgr = function(rawtxs, exons, sqinfo) {
    ##    rawtxs = sanitize_feats(rawtxs, tx_cols)
    if(length(rawtxs) > 0) {
        rawtxs = fill_stack_df(rawtxs, sqinfo = sqinfo)
        rawtxs$tx_id_base = ifelse(is.na(rawtxs$gene), paste("unknown_gene", cumsum(is.na(rawtxs$gene)), sep="_"), rawtxs$gene)
        spltxs = split(rawtxs, rawtxs$tx_id_base)
        txsraw = lapply(spltxs, function(grl) {
            grl$transcript_id = paste(grl$tx_id_base, 1:length(grl), 
                                      sep=".")
            grl$tx_id_base = NULL
            grl
        })
        txslst = GRangesList(txsraw)
        txs = unlist(txslst, use.names=FALSE)
        txs$gene_id = txs$gene
        txs$gene = NULL
        txs$temp_grouping_id=NULL
    }  else if (length(exons) == 0L) {
        txs = GRanges(seqinfo=sqinfo)
    } else {
        message("No transcript features (mRNA) found, using spans of CDSs")
        spl = split(exons, exons$transcript_id)
        txslst = range(spl)
        
        txs = unlist(txslst, use.names=FALSE)
        txs$gene_id = mcols(phead(spl, 1))$gene_id
        seqinfo(txs) = sqinfo
    }
    txs
}


##' @importFrom VariantAnnotation VRanges makeVRangesFromGRanges

make_varvr = function(rawvars, sq, sqinfo) {
    if(length(rawvars) == 0)
        return(VRanges(seqinfo = sqinfo))
    if(is.null(sq)) {
        warning("importing variation features when origin sequence is not included in the file is not currently supported. Skipping ", length(rawvars), " variation features.")
    }
        
    vrs = fill_stack_df(rawvars, sqinfo = sqinfo)
    vrs$temp_grouping_id = NULL
    ## if(any(is.na(vrs$replace))) {
    ##     warning("Removing seemingly unspecified variation features (no /replace)")
    ##     vrs = vrs[!is.na(vrs$replace)]
    ## }

    ## makeVRangesFromGRanges seems to have a bug(?) that requires the
    ## columns used dfor the VRanges core info to be the first 6 in the
    ## granges mcols
    dels = nchar(vrs$replace) == 0L
    vrs[dels] = resize(vrs[dels], width(vrs[dels]) + 1L, fix = "end")
    vrs$replace[dels] = as.character(sq[resize(vrs[dels], 1L)])
    newcols = DataFrame( ref  = as.character(sq[vrs]),
                        alt = vrs$replace,
                        totalDepth = NA_integer_,
                        altDepth = NA_integer_,
                        refDepth = NA_integer_,
                        sampleNames = NA_character_)
    mcols(vrs) = cbind(newcols, mcols(vrs))
    res  = makeVRangesFromGRanges(vrs)
    res
}

make_exongr = function(rawex, cdss, sqinfo) {
    ##exns = sanitize_feats(rawex, exon_cols)
    exns = fill_stack_df(rawex, sqinfo = sqinfo)
    if(is.null(exns)) {

            message("No exons read from genbank file. Assuming sections of CDS are full exons")
        if(length(cdss) > 0) {
            exns = cdss
            exns$type = "exon"
        } else {
            return(GRanges(seqinfo = sqinfo))
        }
            
    } else {
        exns = stack(exns)
    
        hits = findOverlaps(exns, cdss, type = "within", select = "all")
        qh = queryHits(hits)
        qhtab = table(qh)
        dup = as.integer(names(qhtab[qhtab>1]))
        havdups = length(dup) > 0
        if(havdups) {
            ambig = exns[unique(dup)]
            exns = exns[-unique(dup)]
            noduphits = hits[-match(qh, dup)]
            warning("Some exons specified in genbank file have ambiguous relationship to transcript(s). ")
            ambig$transcript_id = paste(ambig$gene_id,
                                        "ambiguous", sep=".")
        } else {
            noduphits = hits
        }

        exns$transcript_id = cdss$transcript_id[subjectHits(noduphits)]
        
    }
    exns$temp_grouping_id = NULL
    exns
}

make_genegr = function(x, sqinfo) {
    res = fill_stack_df(x, sqinfo = sqinfo)
    res$temp_grouping_id = NULL
    if(is.null(res))
        res = GRanges(seqinfo = sqinfo)
    else if(is.null(res$gene)) {
        message("Gene annotations do not have 'gene' label, looking for 'locus_tag' ... ",
                appendLF=FALSE)
        if(!is.null(res$locus_tag)) {
            message("found.")
            res$gene = res$locus_tag
        } else {
            message("not found.")
            stop("Unable to determine gene 'names' for gene annotations. Looked for 'gene' and 'locus_tag'")
        }
    }
    res
}



##' @importFrom GenomeInfoDb seqlevels seqinfo Seqinfo
##' @title GenBank object constructors
##' @description Constructors for \code{GenBankFull} and
##' \code{GenBankAnnot} objects.
##' @rdname make_gbobjs
##' @param rawgbk list. The output of \code{parseGenBank}
##' @param verbose logical. Should informative messages be shown
##' @return A GenBankAnnot (\code{make_gbannot}) or
##' GenBankFull (\code{make_gbfull}) object.
##' @examples
##' prsed = parseGenBank(system.file("sample.gbk", package="genbankr"))
##' gb = make_gbannot(prsed)
##' @export
make_gbannot = function(rawgbk, verbose = FALSE) {
    bf = proc.time()["elapsed"]
    feats = rawgbk$FEATURES
    sq = rawgbk$ORIGIN
    
    typs = sapply(feats, function(x)
        if(length(x) > 0) x$type[1] else NA_character_)
    empty = is.na(typs)
    feats = feats[!empty]
    typs = typs[!empty]
    featspl = split(feats, typs)
    srcs = fill_stack_df(featspl$source)
    circ = grepl("circular", rawgbk$LOCUS)
    ##grab the versioned accession to use as the "genome" in seqinfo
    genom = strsplit(rawgbk$VERSION, " ")[[1]][1]
    sqinfo = Seqinfo(seqlevels(srcs), width(srcs), circ, genom)
    if(verbose)
        message(Sys.time(), " Starting creation of gene GRanges")
    gns = make_genegr(featspl$gene, sqinfo)
    
    if(verbose)
        message(Sys.time(), " Starting creation of CDS GRanges")
    if(!is.null(featspl$CDS))
        cdss = make_cdsgr(featspl$CDS, gns, sqinfo)
    else
        cdss = GRanges(seqinfo = sqinfo)
    if(verbose)
        message(Sys.time(), " Starting creation of exon GRanges")

    
    exns = make_exongr(featspl$exon, cdss = cdss, sqinfo)

    if(verbose)
        message(Sys.time(), " Starting creation of variant VRanges")
    vars = make_varvr(featspl$variation, sq = sq, sqinfo)
 
    
    if(verbose)
        message(Sys.time(), " Starting creation of transcript GRanges")

    txs = make_txgr(featspl$mRNA, exons = exns, sqinfo)
    
    if(verbose)
        message(Sys.time(), " Starting creation of misc feature GRanges")

    ofeats = fill_stack_df(feats[!typs %in% c("gene", "exon", "CDS", "variation",
                                           "mRNA", "source")])

    ofeats$temp_grouping_id = NULL

    if(is.null(ofeats))
        ofeats = GRanges()
    seqinfo(ofeats) = sqinfo
    res = new("GenBankAnnot", genes = gns, cds = cdss, exons = exns,
              transcripts = txs, variations = vars,
              sources = fill_stack_df(feats[typs == "source"]),
              other_features = ofeats,
              accession = rawgbk$ACCESSION,
              version = rawgbk$VERSION,
              locus = rawgbk$LOCUS,
              definition = rawgbk$DEFINITION)
    af = proc.time()["elapsed"]
    if(verbose)
        message(Sys.time(), " - Done creating GenBankAnnot object [ ", af - bf, " seconds ]") 
    res
}
    

##' @rdname make_gbobjs
##' @aliases make_gbfull
##' @export
make_gbfull = function(rawgbk, verbose = FALSE) {
    gba = make_gbannot(rawgbk, verbose = verbose)
    new("GenBankFull", annotations = gba, sequence = rawgbk$ORIGIN)
}


## super fast rbind of data.frame lists from Pete Haverty
.simple_rbind_dataframe <- function(dflist, element.colname) {
    numrows = vapply(dflist, nrow, integer(1))
    if (!missing(element.colname)) {
        list.name.col = factor(rep(names(dflist), numrows), levels=names(dflist))
    }
    dflist = dflist[ numrows > 0 ] # ARGH, if some data.frames have zero rows, factors become integers
    myunlist = base::unlist
    mylapply = base::lapply
    cn = names(dflist[[1]])
    inds = structure(1L:length(cn), names=cn)
    big <- mylapply(inds,
                    function(x) {
        myunlist(
                                        # mylapply(dflist, function(y) { y[[x]] }),
            mylapply(dflist, function(y) { .subset2(y, x) }),
            recursive=FALSE, use.names=FALSE)
    })
    if (!missing(element.colname)) {
        big[[element.colname]] = list.name.col
    }
    class(big) <- "data.frame"
    attr(big, "row.names") <- .set_row_names(length(big[[1]]))
    return(big)
}



cheap_unsafe_data.frame = function(..., lst = list(...)) {
    lens = lengths(lst)
    len = max(lens)
    if(!all(lens == len))
        lst = lapply(lst, rep, length.out = len)

    if(anyDuplicated.default(names(lst)))
        names(lst) =make.unique(names(lst))

    class(lst) = "data.frame"
    attr(lst, "row.names") = .set_row_names(length(lst[[1]]))
    lst
}

 ## microbenchmark(data.frame(x,y),
 ##                as.data.frame(list(x=x, y=y)),
 ## {lst = list(x = x, y =y); class(lst) = "data.frame"; attr(lst, "row.names") = .set_row_names(150)},
 ## cheap_unsafe_data.frame(x=x,y=y),
 ## cheap_unsafe_data.frame(x=x,y=y, x=y, x = y, x = x),
 ## times = 1000)