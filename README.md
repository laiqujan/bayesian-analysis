# Bayesian Data Analysis of Invalid Bug Reports
## Problem
**Case:** In large-scale software development, many bug reports are submitted daily. However, not all of the submitted bug reports describe actual deviations in the system behavior, i.e., they are invalid. Invalid bug reports cost resources and time and make prioritization of valid bug reports difficult 
(Laiq et al., [2022] (https://doi.org/10.1007/978-3-031-21388-5_34)).

**Aim:** This project explores the causal effects of different factors/variables on bug report resolutions (i.e., valid (1) or invalid (0)), such as submitter validity rate, total bug reports submitted, testing level where bug reports are caught and bug report quality or completeness.

 
## Dataset 
We will use open-source (OSS) and closed-source (CSS) data sets. The open data source is made available by (Fan et al., [2018] (https://doi.org/10.1109/TSE.2018.2864217)). I have cleaned data sets using python script.
### Featuers
We have the follwing featuers:
1. **Submitter Validity Rate (SVR):** SVR is a ratio of valid to total bug reports of each submitter.
2. **Submitter Bug Count (SBC):** SBC is the total bug count of each submitter.
3. **Caught Where (CW):** CW is a testing level or place where a bug is detected.
4. **Bug Completness (BC):** CW is the bug completeness weight that indicates the quality of the submitted bug report. It is calculated from textual descriptions: (a) if the bug report has steps to reproduce, (b) if the bug report has stack traces, (c) if the bug report has test case(s), (d) if the bug report has any screenshot or attachment, (e) if the bug report has any code, and (f) if the bug report has patch.
5. **Resolution:** The resolution label of each bug report, i.e., valid or invalid.

# CSS Data
<pre><code>
#Loading Data
d<-read.csv("../css.csv")
str(d)
'data.frame':	N obs. of  5 variables:
 $ SVR       : num  1 1 1 1 0.833 ...
 $ SBC       : int  4 4 4 4 6 84 57 135 33 48 ...
 $ CW        : int  1 1 1 1 1 2 1 2 1 1 ...
 $ BC        : int  2 1 2 1 1 1 2 1 1 4 ...
 $ Resolution: int  1 1 1 1 1 0 1 1 1 1 ...
</code> </pre>
Description of each data type, i.e., type or range of values.

# Distribution Type: 
Bionomial Distribution sepcial case (1/0), aka Bernoulli Distribution (1,p).

# Model Design
## Prior Checks
## Posterior Checks
