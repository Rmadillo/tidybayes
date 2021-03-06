# Tests for spread_samples
#
# Author: mjskay
###############################################################################

import::from(plyr, ldply, .)  #TODO: drop remaining ldplys from this file
import::from(dplyr, `%>%`, inner_join, data_frame)
import::from(lazyeval, lazy)
library(tidyr)

context("spread_samples")


#set up datasets
data(RankCorr, package = "tidybayes")

# subset of RankCorr (for speed)
RankCorr_s = RankCorr[1:10,]

# version of RankCorr with i index labeled
i_labels = c("a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r")
RankCorr_i = recover_types(RankCorr_s, list(i = factor(i_labels)))

# version of RankCorr with i and j indices labeled
i_labels = c("a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r")
j_labels = c("A", "B", "C", "D")
RankCorr_ij = recover_types(RankCorr_s, list(i = factor(i_labels), j = factor(j_labels)))


# tests for helpers ==========================================================

test_that("all_names works on various expressions", {
  expect_equal(all_names(quote(a + b + c[i, j] + 1)), c("a","b","c","i","j"))

  invalid_expr = quote(a + b)
  invalid_expr[[3]] = list() #replace `b` with a list object
  expect_error(all_names(invalid_expr), "Don't know how to handle type `list`")
})


test_that("parse_variable_spec rejects incorrect usage of `|`", {
  expect_error(parse_variable_spec(lazy(a | b | c)),
    "Left-hand side of `|` cannot contain `|`")
  expect_error(parse_variable_spec(lazy(a | cbind(b, c))),
    "Right-hand side of `|` must be exactly one name")
})



# tests for spread_samples ===================================================

test_that("spread_samples correctly rejects missing parameters", {
  data("RankCorr", package = "tidybayes")

  expect_error(spread_samples(RankCorr, c(a, b)),
    "No parameters found matching spec: c\\(a,b\\)")
  expect_error(spread_samples(RankCorr, a[b]),
    "No parameters found matching spec: c\\(a\\)\\[b\\]")
})


test_that("spread_samples works on a simple parameter with no indices", {
  ref = data_frame(
    .chain = as.integer(1),
    .iteration = seq_len(nrow(RankCorr_s)),
    typical_r = RankCorr_s[, "typical_r"]
  )

  expect_equal(spread_samples(RankCorr_s, typical_r), ref)
})


test_that("spread_samples works on a parameter with one unnamed index", {
  ref = ldply(1:18, function(i) {
    data.frame(
      .chain = as.integer(1),
      .iteration = seq_len(nrow(RankCorr_s)),
      i = i,
      tau = RankCorr_s[, paste0("tau[", i, "]")]
    )
  })

  expect_equal(spread_samples(RankCorr_s, tau[i]) %>% arrange(i), ref)
})

test_that("spread_samples works on a parameter with one named index", {
  ref = ldply(1:18, function(i) {
    data.frame(
      .chain = as.integer(1),
      .iteration = seq_len(nrow(RankCorr_i)),
      i = i_labels[i],
      tau = RankCorr_i[, paste0("tau[", i, "]")]
    )
  })

  expect_equal(spread_samples(RankCorr_i, tau[i]) %>% arrange(i), ref)
})

test_that("spread_samples works on a parameter with one anonymous wide index", {
  ref = data.frame(
    .chain = as.integer(1),
    .iteration = seq_len(nrow(RankCorr_s))
  )
  for (i in 1:18) {
    refcol = data.frame(RankCorr_s[, paste0("tau[", i, "]")])
    names(refcol) = paste0("tau.", i)
    ref = cbind(ref, refcol)
  }

  expect_equal(spread_samples(RankCorr_s, tau[..]), ref)
})


test_that("spread_samples works on a parameter with one named wide index", {
  ref = data.frame(
    .chain = as.integer(1),
    .iteration = seq_len(nrow(RankCorr_i))
  )
  for (i in 1:18) {
    refcol = data.frame(RankCorr_i[, paste0("tau[", i, "]")])
    names(refcol) = i_labels[i]
    ref = cbind(ref, refcol)
  }

  expect_equal(spread_samples(RankCorr_i, tau[i] | i), ref)
})


test_that("spread_samples works on a parameter with two named indices", {
  ref = ldply(1:4, function(j) {
    ldply(1:18, function(i) {
      data.frame(
        .chain = as.integer(1),
        .iteration = seq_len(nrow(RankCorr_ij)),
        i = i_labels[i],
        j = j_labels[j],
        b = RankCorr_ij[, paste0("b[", i, ",", j, "]")]
      )
    })
  })

  expect_equal(spread_samples(RankCorr_ij, b[i, j]) %>% arrange(j, i), ref)
})


test_that("spread_samples works on a parameter with two named indices, one that is wide", {
  ref = ldply(1:4, function(j) {
    ldply(1:18, function(i) {
      data.frame(
        .chain = as.integer(1),
        .iteration = seq_len(nrow(RankCorr_ij)),
        i = i_labels[i],
        j = j_labels[j],
        b = RankCorr_ij[, paste0("b[", i, ",", j, "]")]
      )
    })
  }) %>%
    spread(j, b)

  expect_equal(spread_samples(RankCorr_ij, b[i, j] | j) %>% arrange(.iteration), ref)
})

test_that("spread_samples works on a parameter with one named index and one wide anonymous index", {
  ref = ldply(1:4, function(j) {
    ldply(1:18, function(i) {
      data.frame(
        .chain = as.integer(1),
        .iteration = seq_len(nrow(RankCorr_i)),
        i = i_labels[i],
        j = paste0("b.", j),
        b = RankCorr_i[, paste0("b[", i, ",", j, "]")]
      )
    })
  }) %>%
    spread(j, b)

  expect_equal(spread_samples(RankCorr_i, b[i, ..]) %>% arrange(.iteration), ref)
})

test_that("spread_samples does not allow extraction of two variables simultaneously with a wide index", {
  error_message = "Cannot extract samples of multiple variables in wide format."
  expect_error(spread_samples(RankCorr_s, c(tau, typical_mu)[..]), error_message)
  expect_error(spread_samples(RankCorr_s, c(tau, typical_mu)[i] | i), error_message)
})

test_that("spread_samples correctly extracts multiple variables simultaneously", {
  expect_equal(spread_samples(RankCorr_i, c(tau, typical_mu)[i]),
    spread_samples(RankCorr_i, tau[i]) %>%
      inner_join(spread_samples(RankCorr_i, typical_mu[i]), by = c(".chain", ".iteration", "i"))
  )
  expect_equal(spread_samples(RankCorr_i, c(tau, typical_mu, u_tau)[i]),
    spread_samples(RankCorr_i, tau[i]) %>%
      inner_join(spread_samples(RankCorr_i, typical_mu[i]), by = c(".chain", ".iteration", "i")) %>%
      inner_join(spread_samples(RankCorr_i, u_tau[i]), by = c(".chain", ".iteration", "i"))
  )
  expect_equal(spread_samples(RankCorr_i, cbind(tau)[i]),
    spread_samples(RankCorr_i, c(tau)[i]))
  expect_equal(spread_samples(RankCorr_i, cbind(tau, typical_mu)[i]),
    spread_samples(RankCorr_i, c(tau, typical_mu)[i]))
  expect_equal(spread_samples(RankCorr_i, cbind(tau, typical_mu, u_tau)[i]),
    spread_samples(RankCorr_i, c(tau, typical_mu, u_tau)[i]))
})

test_that("spread_samples correctly extracts multiple variables simultaneously when those variables have no indices", {
  RankCorr_t = RankCorr_s
  dimnames(RankCorr_t)[[2]][[1]] <- "tr2"

  ref1 = spread_samples(RankCorr_t, typical_r)
  expect_equal(spread_samples(RankCorr_t, c(typical_r)), ref1)

  ref2 = spread_samples(RankCorr_t, tr2) %>%
    inner_join(spread_samples(RankCorr_t, typical_r), by = c(".chain", ".iteration"))
  expect_equal(spread_samples(RankCorr_t, c(tr2, typical_r)), ref2)
})

test_that("spread_samples multispec syntax joins results correctly", {
  ref = spread_samples(RankCorr_s, typical_r) %>%
    inner_join(spread_samples(RankCorr_s, tau[i]), by = c(".chain", ".iteration")) %>%
    inner_join(spread_samples(RankCorr_s, b[i, v]), by = c(".chain", ".iteration", "i"))

  expect_equal(spread_samples(RankCorr_s, typical_r, tau[i], b[i, v]), ref)
})

test_that("spread_samples multispec with different indices retains grouping information with all indices", {
  groups_ = RankCorr_s %>%
    spread_samples(typical_r, tau[i], b[i, j]) %>%
    groups() %>%
    as.character()

  expect_equal(groups_, c("i", "j"))
})

test_that("groups from spread_samples retain factor level names", {
  samples = RankCorr_i %>% spread_samples(tau[i])

  expect_equivalent(attr(samples, "labels")$i, factor(i_labels))
})

test_that("empty indices are dropped", {
  ref = RankCorr_s %>%
    spread_samples(tau[i]) %>%
    ungroup() %>%
    select(-i)

  expect_equal(spread_samples(RankCorr_s, tau[]), ref)

  ref2 = RankCorr_s %>%
    spread_samples(b[i, j]) %>%
    group_by(j) %>%
    select(-i)

  expect_equal(spread_samples(RankCorr_s, b[, j]), ref2)

  ref3 = RankCorr_s %>%
    spread_samples(b[i, j]) %>%
    group_by(i) %>%
    select(-j)

  expect_equal(spread_samples(RankCorr_s, b[i, ]), ref3)

  ref4 = RankCorr_s %>%
    spread_samples(b[i, j]) %>%
    ungroup() %>%
    select(-i, -j)

  expect_equal(spread_samples(RankCorr_s, b[, ]), ref4)
})

test_that("indices with existing names as strings are made wide as strings with `..`", {
  RankCorr_t = RankCorr_s
  dimnames(RankCorr_t)[[2]][1] = "x[a]"
  dimnames(RankCorr_t)[[2]][2] = "x[b]"

  ref = RankCorr_t %>%
    spread_samples(x[k]) %>%
    spread(k, x) %>%
    rename(x.a = a, x.b = b)

  expect_equal(spread_samples(RankCorr_t, x[..]), ref)
})

test_that("regular expressions for parameter names work on non-indexed parameters", {
  ref = spread_samples(RankCorr_s, typical_r)

  expect_equal(spread_samples(RankCorr_s, `typical..`, regex = TRUE), ref)
})

test_that("regular expressions for parameter names work on indexed parameters", {
  ref = spread_samples(RankCorr_s, c(tau, u_tau)[i])

  expect_equal(spread_samples(RankCorr_s, `.*tau`[i], regex = TRUE), ref)
})

test_that("parameter names containing regex special chars work", {
  RankCorr_t = RankCorr_s
  dimnames(RankCorr_t)[[2]][[1]] = "(Intercept("

  ref = RankCorr_t %>%
    as_sample_tibble() %>%
    select(.chain, .iteration, `(Intercept(`)

  expect_equal(spread_samples(RankCorr_t, `(Intercept(`), ref)
})
