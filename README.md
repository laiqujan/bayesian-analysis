# Bayesian Data Analysis of Invalid Bug Reports
## Problem
**Case:** In large-scale software development, many bug reports are submitted daily. However, not all of the submitted bug reports describe actual deviations in the system behavior, i.e., they are invalid. Invalid bug reports cost resources and time and make prioritization of valid bug reports difficult 
(Laiq et al., [2022] (https://doi.org/10.1007/978-3-031-21388-5_34)).

**Aim:** This project explores the causal effects of different factors/variables on bug report resolutions (i.e., valid (1) or invalid (0)), such as submitter validity rate, total bug reports submitted, testing level where bug reports are caught and bug report quality or completeness.

 
## Dataset 
We will use open-source (OSS) and closed-source (CSS) data sets. The open data source is made available by (Fan et al., [2018] (https://doi.org/10.1109/TSE.2018.2864217)). I have cleaned data sets using python script.
### Variables
We have the follwing variables:
1. **Submitter Validity Rate (SVR):** SVR is a ratio of valid to total bug reports of each submitter. People with a high validity rate are likely to submit valid bug reports. Thus, **SVR** directly influences the **Resolution**, i.e., valid or invalid, **SVR**&#8594;**Resolution**.

2. **Submitter Bug Count (SBC):** SBC is the total bug count of each submitter. People who have submitted more bug reports are considered experienced, and experience directly influences the **Resolution**, **SBC**&#8594;**Resolution**, i.e., submitters with more bug count will likely submit valid bug reports or bug reports with high quality. 

3. **Caught Where (CW)**: The CW variable refers to the testing environment or stage where a bug is discovered. This variable is being analyzed to see if the testing environment has an impact on the validity of a bug report. If the testing environment is flawed or if the phase of testing in which the bug was discovered was not done correctly, it is possible that invalid bug reports may be submitted. The goal of this analysis is to determine whether the testing environment plays a role in the validity of bug reports.

4. **Bug Completness (BC):** BC is the bug completeness weight that indicates the quality of the submitted bug report. It is calculated from textual descriptions: (a) if the bug report has steps to reproduce, (b) if the bug report has stack traces, (c) if the bug report has test case(s), (d) if the bug report has any screenshot or attachment, (e) if the bug report has any code, and (f) if the bug report has patch. 
In general, having a complete and detailed bug report can help determine whether a bug report is valid or not. However, it may not always be possible to accurately assess the validity of a bug report just by looking at its content, as people may not always follow guidelines for writing bug reports. Despite this, it is still worth considering the completeness of a bug report as one factor in determining its validity.

5. **Resolution:** The resolution label of each bug report, i.e., valid or invalid. This is our outcome and dependent variable influenced by the rest.

# Closed-source Data
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
SVR and SBC are numerical variables. SVR range is from 0 to 1, showing the percentage/ratio validity rate. However, SBC is a positive integer count, i.e., N >= 0.
CW is a nominal or categorical variable representing the testing level or phase where a bug was detected. BC is weighted from 1 to 6, 1 is a default value for each bug report, and weight is added +1 for each factor present in a bug report; see the above description of BC.

## Likelihoods 
The outcome variable **Resolution** takes 0 or 1, and for this type of data, **Binomial Distribution** with special case (1/0) is used, also defined as a **Bernoulli Distribution**.
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
## Priors
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
dens(p, adj=0.1, main = 'Prior: dnorm(0,10)')
</code></pre>
As shown in the figure below, the chosen prior is not good; the model assumes that either event always happens or never happens before it sees the data.
![Prior Check -1](/images/m1.0-prior-check.png)

Let's model with something that makes sense dnorm(0,1)
<pre><code>
 m1.1 <- quap(
  alist(
    Resolution ~ dbinom( 1 , p ) ,
    logit(p) <- a,
    a ~ dnorm( 0 , 1)
  ) , data=d )
#get prior samples
prior <- extract.prior(m1.1, 1e4)
#convert to logistic
p <- inv_logit(prior$a)
#plot
dens(p, adj=0.1,main = 'Prior: dnorm(0,1)')
</code></pre>
Seems better for binomial intercept - dnorm(0,1). We will use that for upcoming models. We will add the remaining predictors to the model and for them we will use dnorm (0,0.5). Furthermore, instead of **quap**, we will turn to our new friend **Hamiltonian Monte Carlo** to approximate the posterior.
![Prior Check -2](/images/m1.1-prior-check.png)
## Models
Let's prepare our data list:
<pre><code>
#We will first standardize SBC and SVR.
d$SBC<-standardize(d$SBC)
d$SVR<-standardize(d$SVR)
#Creating data list
dat_list <- list(
  Resolution = d$Resolution,
  SVR = d$SVR,
  SBC = d$SBC,
  CW = d$CW,
  BC = d$BC) 
</code></pre>
Time for Markov, we call it using ulam
<pre><code>
m1.3 <- ulam(
  alist(
    Resolution ~ dbinom( 1 , p ) ,
    logit(p) <- a[CW] + b[BC] + VR*SVR+ Count*SBC,
    a[CW] ~ dnorm( 0 , 1),
    b[BC] ~ dnorm( 0 , 0.5),
    VR ~ dnorm( 0 , 0.5),
    Count ~ dnorm( 0 , 0.5)
  ) , data=dat_list , chains=4 , log_lik=TRUE)
</code></pre>

## Posterior Results
Check diagnostics.
<pre><code>
precis( m1.3 , depth=2 )
       mean   sd  5.5% 94.5% n_eff Rhat4
a[1]   0.83 0.22  0.47  1.17   293  1.02
a[2]   1.05 0.22  0.69  1.38   341  1.02
a[3]   0.69 0.67 -0.37  1.75  2001  1.00
a[4]   1.13 0.27  0.70  1.56   448  1.01
a[5]   1.29 0.70  0.25  2.44  1954  1.00
a[6]   0.70 0.82 -0.52  2.05  1707  1.00
a[7]   0.82 0.24  0.43  1.21   414  1.01
a[8]   0.52 0.67 -0.54  1.60  2163  1.00
a[9]   1.11 0.75 -0.03  2.37  2109  1.00
a[10]  1.71 0.52  0.90  2.55  1247  1.01
a[11]  1.15 0.42  0.51  1.85   830  1.01
a[12]  0.92 0.23  0.53  1.29   468  1.01
a[13]  0.72 0.29  0.26  1.19   542  1.01
a[14]  0.95 0.77 -0.23  2.23  2049  1.00
b[1]   0.98 0.21  0.64  1.32   302  1.02
b[2]   0.75 0.21  0.42  1.09   317  1.02
b[3]   0.89 0.23  0.54  1.25   397  1.02
b[4]   0.88 0.30  0.40  1.37   758  1.01
VR     1.08 0.06  0.98  1.18  2066  1.00
Count -0.12 0.06 -0.21 -0.03  1789  1.00 
</code></pre>

The values of "n_eff" and "Rhat" appear to be normal, indicating that the model is likely performing well. However, we will also check TRACE RANK PLOT, or TRANK PLOT. Additionally, we will need to put more effort into interpreting the "precis" results. We will revisit this after examining "Trankplots".

</code></pre>
<pre><code>
#Traceplots
trankplot(m1.3)
</code></pre>
![TrankPlot](/images/trankplot1.3v1.png)

Let's extract posteriors and plot:

Plot CW - caught where is a place or testing level where a bug was detected.

<pre><code>
post <- extract.samples(m1.3)
post_a <- inv_logit( post$a)
plot( precis( as.data.frame(post_a) ))
</code></pre>
The graph demonstrates that V5, V10, and V11 tend to be associated with valid bug reports, while V13, V8, and V3 are slightly more likely to produce 
invalid bug reports.

![CW Plot](/images/precis-plot-for-cw.png)

Let's plot BC - bug completeness/quality.
<pre><code>
post <- extract.samples(m1.3)
post_b <- inv_logit( post$b)
plot( precis( as.data.frame(post_b) ))
</code></pre>
The graph indicates that V4 and V3 are more likely to produce valid bug reports, while treatment V2 is slightly less favorable for valid bug reports. The default treatment V1 (which means no factor was identified in the bug report) is more favorable for valid bug reports. As mentioned earlier, it may not be possible to determine the relationship between the factors mentioned and the bug report validity by calculating them from the report text, as people often do not follow bug writing guidelines. 
![BC Plot](/images/precis-plot-for-bc.png)

# Open-source Data
We will apply the same model and process to open-source data to see how it performs. The proportion of invalid bug reports is generally higher in open-source systems, and the quality of bug reports is lower compared to closed-source systems.

<pre><code>
#Loading Data
d<-read.csv("../oss.csv")
str(d)
'data.frame':	5601 obs. of  5 variables:
 $ SVR       : num  0.844 0.783 0.927 0.776 0.534 ...
 $ SBC       : int  1479 1168 382 1786 480 1843 0 0 0 141 ...
 $ SRBC      : int  50 36 26 41 36 123 0 0 0 82 ...
 $ BC        : int  1 2 1 3 1 1 1 1 1 1 ...
 $ Resolution: int  1 1 1 1 1 1 1 1 1 1 ...
</code> </pre>
We have one new variable, Submitter Recent Bug Count (SBC); this indicates how active is bug submitter is in the community (i.e., how many bug reports have been submitted by a particular submitter in the last 90 days). Software systems evolve rapidly. Thus inactive people are likely to submit invalid bug reports. We did not use that feature for CSS because, in CSS, people keep themselves updated. Thus, unlikely to have any effect.

## Models
Let's prepare our data list:
<pre><code>
#We will first standardize SBC, SRBC, and SVR.
d$SBC<-standardize(d$SBC)
d$SRBC<-standardize(d$SRBC)
d$SVR<-standardize(d$SVR)
#Creating data list
dat_list <- list(
  Resolution = d$Resolution,
  SVR = d$SVR,
  SBC = d$SBC,
  SRBC = d$SRBC,
  BC = d$BC) 
</code></pre>
Time for Markov, we call it using ulam
<pre><code>
m1.4 <- ulam(
  alist(
    Resolution ~ dbinom( 1 , p ) ,
    logit(p) <- a[BC] + VR*SVR + Count*SBC + RCount*SRBC,
    a[BC] ~ dnorm( 0 , 1),
    RCount ~ dnorm( 0 , 0.5),
    VR ~ dnorm( 0 , 0.5),
    Count ~ dnorm( 0 , 0.5)
  ) , data=dat_list , chains=4 , log_lik=TRUE)
</code></pre>

## Posterior Results
Check diagnostics.
<pre><code>
precis( m1.4 , depth=2 )
        mean   sd  5.5% 94.5% n_eff Rhat4
a[1]    0.63 0.04  0.57  0.70  2595     1
a[2]    0.61 0.05  0.54  0.69  2482     1
a[3]    0.68 0.14  0.46  0.92  2476     1
a[4]    1.49 0.62  0.51  2.50  2760     1
RCount  0.05 0.05 -0.04  0.13  1880     1
VR      0.77 0.03  0.72  0.82  2548     1
Count  -0.09 0.05 -0.18 -0.01  1829     1
</code></pre>

The values of "n_eff" and "Rhat" appear to be normal, indicating that the model is likely performing well. However, we will also check TRACE RANK PLOT, or TRANK PLOT. Additionally, we will need to put more effort into interpreting the "precis" results. We will revisit this after examining "Trankplots".

</code></pre>
<pre><code>
#Trankplots
trankplot(m1.4)
</code></pre>
![TrankPlot](/images/trankplot1.4v1.png)

Let's extract posteriors and plot:

Let's plot BC - bug completeness/quality.
<pre><code>
post <- extract.samples(m1.4)
post_b <- inv_logit( post$b)
plot( precis( as.data.frame(post_b) ))
</code></pre>
The graph indicates that the presence of weighted factors does produce/favors valid bug reports. 
![BC Plot](/images/precis-plot-for-bcm1.4.png)

Let's plot remaining SVR, SBC, and RBC.
<pre><code>
#Plot model precis 
plot( precis(m1.4))
</code></pre>
As shown in the figure, the submitter validity rate significantly affects the validity of bug reports, i.e., people with a high validity rate are likely to submit valid bug reports.
![Precis Plot](/images/precis-plot-for-m1.4.png)
# Material Used

1. Book: Statistical Rethinking : A Bayesian Course with Examples in R and STAN By Richard McElreath, https://doi.org/10.1201/9780429029608
2. https://www.youtube.com/@rmcelreath
