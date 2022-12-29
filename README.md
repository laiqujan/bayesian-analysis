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
SVR and SBC are numerical variables. SVR range is from 0 to 1, showing the percentage/ratio validity rate. However, SBC is a positive integer count, i.e., N >= 0.
CW is a nominal or categorical variable representing the testing level or phase where a bug was detected. BC is weighted from 1 to 6, 1 is a default value for each bug report, and weight is added +1 for each factor present in a bug report; see the above description of BC.

# Likelihoods 
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
# Models
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

## Posterior Results:
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

The values of "n_eff" and "Rhat" appear to be normal, indicating that the model is likely performing well. However, we will also check TRACE RANK PLOT, or TRANK PLOT. Additionally, we will need to put more effort into interpreting the "precis" results. We will revisit this after examining "Trankplots" and "Traceplots".

</code></pre>
<pre><code>
#Traceplots
traceplot(1.3)
</code></pre>
![TrankPlot](/images/trankplot1.3v1.png)

Let's extract posteriors and plot:

Plot CW - caught where is a place or testing level where a bug was detected.

<pre><code>
post <- extract.samples(m1.3)
post_a <- inv_logit( post$a)
plot( precis( as.data.frame(post_a) ))
</code></pre>
![Prior Check -2](/images/precis-plot-for-cw.png)

The graph demonstrates that V5, V10, and V11 tend to be associated with valid bug reports, while V13, V8, and V3 are slightly more likely to produce 
invalid bug reports.

Let's plot BC - bug completeness/quality.
<pre><code>
post <- extract.samples(m1.3)
post_b <- inv_logit( post$b)
plot( precis( as.data.frame(post_b) ))
</code></pre>
![Prior Check -2](/images/precis-plot-for-bc.png)

In the figure, we can see that bug completeness results are opposite to what we were expecting. The default treatment V1 means no factor was found in the bug report, but the results favor valid instead of invalid bug reports. V1 to V4 results seem okay. As I said in this start, it may not be possible to reveal the relationship by calculating the factors mentioned earlier from the bug report.

# Sanity check of the posterior
We will use the built-in function **postcheck** for a sanity check.

<pre><code>
#Sanity check of the posterior
postcheck(m1.3, window = 20)
</code></pre>

### Material Used

1. Book: Statistical Rethinking : A Bayesian Course with Examples in R and STAN By Richard McElreath, https://doi.org/10.1201/9780429029608
2. https://www.youtube.com/@rmcelreath
