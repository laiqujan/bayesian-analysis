# Bayesian Data Analysis of Invalid Bug Reports
## Problem
**Case:** In large-scale software development, many bug reports are submitted daily. However, not all of the submitted bug reports describe actual deviations in the system behavior, i.e., they are invalid. Invalid bug reports cost resources and time and make prioritization of valid bug reports difficult 
(Laiq et al., [2022] (https://doi.org/10.1007/978-3-031-21388-5_34)).

**Aim:** This project explores the causal effects of different factors/variables on bug report resolutions (i.e., valid (1) or invalid (0)), such as submitter validity rate, total bug reports submitted, testing level where bug reports are caught and bug report quality or completeness.

 
## Dataset 
We will use open-source (OSS) and closed-source (CSS) data sets. The open data source is made available by (Fan et al., [2018] (https://doi.org/10.1109/TSE.2018.2864217)). I have cleaned data sets using python script.
### Variables
We have the follwing variables:
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

# Likelihoods 
The outcome variable **Resolution** takes 0 or 1, and for this type of data, **Binomial Distribution** with special case (1/0), also defined with **Bernoulli Distribution**, is used.
<pre><code>y~ binomial ( n , p ), with n=1 y~ binomial ( 1 , p ) </code></pre>

**Logistic Regression:** When data is organized into singular-trial cases, i.e., the outcome is 0 or 1. We will use the logit link function,i.e., logit(p).
Precisely, our model, according to our aim stated above, looks like this:
<pre><code>
  Resolution ~ dbinom( 1 , p ) , y~ binomial ( 1 , p )
  logit(p) <- a[CW] + b[BC]+ VR*SVR + Count*SBC*
  a[CW] ~ to be determined
  b[BC] ~ to be determined
  VR ~ to be determined
  Count ~ to be determined
 </code></pre>
 
# Priors
We need to determine the priors for our predictor variables of the model. We will start with a simple intercept model using binomial distribution and do prior checks.
<pre><code>
#Let's use the flat prior, setting  a ~ dnorm( 0 , 10 )
m1.0 <- quap(
  alist(
    Resolution ~ dbinom( 1 , p ) ,
    logit(p) <- a,
    a ~ dnorm( 0 , 10 )
  ) , data=d )
 </code></pre>
 Now Let's sample prior and inspect what the model thinks before seeing data.
<pre><code>
 #get prior samples
prior <- extract.prior(m1.0, 1e4)
#convert to logistic
p <- inv_logit(prior$a)
#plot
dens(p, adj=0.1)

#Not a good prior model thinks that either event always happens or not even before it sees the data
#Let's model with something that makes sense dnorm(0,1)

</code></pre>
# Models

### Material Used
1. Book: Statistical Rethinking : A Bayesian Course with Examples in R and STAN By Richard McElreath, https://doi.org/10.1201/9780429029608
2. https://www.youtube.com/@rmcelreath
