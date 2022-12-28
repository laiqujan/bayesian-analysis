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

2. **Submitter Bug Count (SBC):** SBC is the total bug count of each submitter. People who have submitted more bug reports are considered experienced, and experience directly influences the **Resolution**, **SBC**&#8594;**Resolution**, i.e., submitters with more bug count will likely submit valid bug reports. 

3. **Caught Where (CW)**: CW is a testing level or place where a bug is detected/caught. This variable is used to analyze if the testing level affects the validity of a bug report. A particular testing level may be poor, or the phase where the bug was detected does something wrong. Thus, invalid bug reports are submitted by them.

4. **Bug Completness (BC):** CW is the bug completeness weight that indicates the quality of the submitted bug report. It is calculated from textual descriptions: (a) if the bug report has steps to reproduce, (b) if the bug report has stack traces, (c) if the bug report has test case(s), (d) if the bug report has any screenshot or attachment, (e) if the bug report has any code, and (f) if the bug report has patch. 
In reality, bug completeness could help distinguish valid or invalid bug reports. However, it may not be possible to reveal the relationship by calculating the factors mentioned earlier from the bug report. As I said, in reality, it should, but people often do not follow the bug report guidelines. Thus it is hard to distinguish valid or invalid bug reports based on these factors in the text. Nevertheless, we will see how it performs.

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

#Let's model with something that makes sense dnorm(0,1)
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
#Time for Markov, we call it using ulam
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
a[1]   0.78 0.21  0.46  1.11   465     1
a[2]   1.00 0.21  0.67  1.34   428     1
a[3]   0.07 0.98 -1.47  1.64  2903     1
a[4]   0.11 0.99 -1.48  1.68  2481     1
a[5]   0.64 0.67 -0.37  1.74  2123     1
a[6]   1.09 0.26  0.68  1.51   779     1
a[7]   1.30 0.70  0.24  2.44  2045     1
a[8]   0.68 0.79 -0.54  1.97  2693     1
a[9]   0.77 0.23  0.41  1.14   556     1
a[10] -0.31 0.82 -1.61  1.02  2682     1
a[11]  0.45 0.69 -0.63  1.61  2567     1
a[12]  1.05 0.74 -0.09  2.26  2947     1
a[13]  1.68 0.52  0.90  2.53  2034     1
a[14]  0.17 0.92 -1.28  1.69  2753     1
a[15]  0.69 0.90 -0.72  2.17  2976     1
a[16] -0.10 0.84 -1.42  1.30  2345     1
a[17]  1.10 0.40  0.48  1.75  1652     1
a[18] -0.18 0.85 -1.58  1.20  2890     1
a[19]  0.48 0.90 -0.95  1.87  2804     1
a[20] -0.64 0.91 -2.05  0.85  2681     1
a[21]  0.87 0.23  0.51  1.25   468     1
a[22]  0.10 0.97 -1.40  1.68  2554     1
a[23]  0.40 0.91 -1.09  1.90  2191     1
a[24]  0.67 0.29  0.21  1.14   752     1
a[25]  0.76 0.84 -0.53  2.11  2405     1
a[26]  0.67 0.85 -0.62  2.03  2657     1
a[27]  0.94 0.74 -0.21  2.14  2460     1
a[28]  0.09 0.98 -1.45  1.66  2405     1
b[1]   1.03 0.20  0.71  1.34   430     1
b[2]   0.80 0.20  0.48  1.11   460     1
b[3]   0.93 0.21  0.58  1.26   462     1
b[4]   0.86 0.29  0.41  1.33  1163     1
b[5]   0.05 0.50 -0.73  0.84  2955     1
VR     1.09 0.06  0.99  1.19  2196     1
Count -0.12 0.06 -0.21 -0.03  2155     1
</code></pre>

The values of n_eff and Rhat seem okay. Let's check Trankplots and Traceplots.

<pre><code>
#trankplots
trankplot(m1.3)

</code></pre>
<pre><code>
#traceplots
traceplot(1.3)
</code></pre>

Let's extract posteriors and plot:

Plot cw - caught where place or testing level where bug was detected
<pre><code>
post <- extract.samples(m1.3)
post_a <- inv_logit( post$a)
plot( precis( as.data.frame(post_a) ))
</code></pre>
![Prior Check -2](/images/precis-plot-for-cw.png)

In figure, we can see xyz level tends to produce valid bug reports likewise, tt level produce invalid bug reports...
Plot bug completeness quality - treatments from 1-6
<pre><code>
post <- extract.samples(m1.3)
post_b <- inv_logit( post$b)
plot( precis( as.data.frame(post_b) ))
</code></pre>
![Prior Check -2](/images/precis-plot-for-bc.png)

In figure, we can see bug completnes do not show positive impact...this could be ...issue with the way we calucluate the bug quality. however, in reality it should be cause for valid bug reports. However, we will see what happens with closed source data.

# Sanity check of the posterior
We will use the built-in function **postcheck** for a sanity check.

<pre><code>
#Sanity check of the posterior
postcheck(m1.3, window = 20)
</code></pre>

### Material Used

1. Book: Statistical Rethinking : A Bayesian Course with Examples in R and STAN By Richard McElreath, https://doi.org/10.1201/9780429029608
2. https://www.youtube.com/@rmcelreath
