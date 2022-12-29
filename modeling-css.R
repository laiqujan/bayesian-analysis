#import
library(rethinking)
d<-read.csv(".../css.csv")

# Group the data frame by cw and summarize the count of each group
df_summary <- d %>% 
  group_by(CW) %>% 
  summarize(count = n())

# filtering rows with CW less than 5
df_filtered <- df_summary %>% filter(count >= 5)

df_final <- inner_join(d, df_filtered, by = "CW")

#stat
simplehist(df_final$CW, ylim=c(0,10), xlab = "response for CW", bty="n")

# group the data frame by BC and summarize the count of each group
df_summary <- df_final %>% 
  group_by(BC) %>% 
  summarize(count = n())

# filtering rows with BC less than 5
df_filtered <- df_summary %>% filter(count >= 5)

df_final1 <- inner_join(df_final, df_filtered, by = "BC")

unique_values <- unique(d$CW)
# for loop that iterates over the sequence 
j = 1
for (i in unique_values) {
  df_final1 <- df_final1 %>% mutate(CW = ifelse(CW == i, j, CW))
  j=j+1
}

simplehist(df_final1$CW, ylim=c(0,50), xlab = "response for BC", bty="n")

#assign df_final1 to d for simplification
d<-df_final1

#str(d)
#QUAP
m1.0 <- quap(
  alist(
    Resolution ~ dbinom( 1 , p ) ,
    logit(p) <- a,
    a ~ dnorm( 0 , 10 )
  ) , data=d )
precis(m1.0)

#Prior check
#get prior samples
prior <- extract.prior(m1.0, 1e4)
#convert to logistic
p <- inv_logit(prior$a)
#plot
dens(p, adj=0.1, main = 'Prior: dnorm(0,10)')
#Not a good prior model thinks that either event always happen or not even before seeing data

'''
#let model with dnorm(0,1.5)
m1.1 <- quap(
  alist(
    Resolution ~ dbinom( 1 , p ) ,
    logit(p) <- a,
    a ~ dnorm( 0 , 1.5)
  ) , data=d )

#Prior check
#get prior samples
prior <- extract.prior(m1.1, 1e4)
#convert to logistic
p <- inv_logit(prior$a)
#plot
dens(p, adj=0.1)
#not bad, but we can improve, lets try with dnorm(0,1)
'''
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
#Seems better for binomial intercept - dnorm(0,1). We will use that for upcoming models.
precis(m1.1)
#Let's add one more variable to the model submitters validity rate (SVR)
#model
m1.2 <- quap(
  alist(
    Resolution ~ dbinom( 1 , p ) ,
    logit(p) <- a + VR*SVR,
    a ~ dnorm( 0 , 1.5 ),
    VR ~ dnorm( 0 , 10 ) #lets use this and we will see in prior check
  ) , data=d )
#prior check
#get prior samples
prior <- extract.prior(m1.2, 1e4)
#convert to logistic
p <- inv_logit(prior$VR)
#plot
dens(p, adj=0.1)
#not good, lets try dnorm(0,0.5)
'''
m1.3 <- quap(
  alist(
    Resolution ~ dbinom( 1 , p ) ,
    logit(p) <- a + VR*SVR,
    a ~ dnorm( 0 , 1.5 ),
    VR ~ dnorm( 0 , 0.5) 
  ) , data=d )

#get prior samples
prior <- extract.prior(m1.3, 1e4)
#convert to logistic
p <- inv_logit(prior$VR)
#lines(dens(p))
#plot
dens(p, adj=0.1)
#seems okay, we will use this for upcoming models

#posterior analysis
precis(m1.3)

#make sense

#getting posterior distribution data	
post <- extract.samples(m1.3)
p_a <- inv_logit( post$a)
plot( precis( as.data.frame(p_a) ) , xlim=c(0,1) )
p_vr <- inv_logit( post$VR)

#creating data frame
dfpost<-data.frame(p_a,p_vr)
plot( precis(dfpost) , xlim=c(0,1) )

#getting posterior distribution data	
a <- link( m1.3)
str(a)

#generating sequence of data
vr_seq<-seq(from=0, to=1,by=0.001)
#linking points to posterior prediction
res<-link(m1.3,data = data.frame(SVR=vr_seq))
#plotting
plot(Resolution~SVR, d,type="n", ylab="R", xlab= "VR")
for(i in 1:100)
  points(vr_seq,res[i,],pch=16,col=col.alpha(rangi2,0.1))

sim.vr <- sim( m1.3 , data=list(SVR=vr_seq) )
str(sim.vr)

d$SBC<-standardize(d$SBC)
d$SVR<-standardize(d$SVR)
#adding the remaining variables to the model
m1.4 <- quap(
  alist(
    Resolution ~ dbinom( 1 , p ) ,
    logit(p) <- a[CW] + VR*SVR + BC*SBC,
    a[CW] ~ dnorm( 0 , 1.5 ),
    BC ~ dnorm( 0 , 1),
    VR ~ dnorm( 0 , 0.5)
  ) , data=d )

precis(m1.4, depth = 2)
#getting posterior distribution data	
post <- extract.samples(m1.5)
p_a <- inv_logit( post$VR)
plot( precis( as.data.frame(p_a) ) , xlim=c(0,1) )

dat_list_2 <- list(Resolution = d1$Resolution,BC1 = d1$BC1,BC2 = d1$BC2,
                   BC3 = d1$BC3,BC4 = d1$BC4,BC5 = d1$BC5,BC6 = d1$BC6)   
m1.5 <- ulam(
  alist(
    Resolution ~ dbinom( 1 , p ) ,
    logit(p) <- a1[BC1] + a2[BC2] + a3[BC3] + a4[BC4] + a5[BC5] +a6[BC6],
    a1[BC1] ~ dnorm( 0 , 1),
    a2[BC2] ~ dnorm( 0 , 1),
    a3[BC3] ~ dnorm( 0 , 1),
    a4[BC4] ~ dnorm( 0 , 1),
    a5[BC5] ~ dnorm( 0 , 1),
    a6[BC6] ~ dnorm( 0 , 1)
    
  ) , data=dat_list_2 , chains=4 , log_lik=TRUE)

precis( m1.5 , depth=2 )
plot( precis( m1.5 , depth=2 ) )

post1 <- extract.samples(m1.5)
post_a <- inv_logit( post1$a2)
plot( precis( as.data.frame(post_a) ))



dat_list_1 <- list(Resolution = d1$Resolution,BC1 = d1$BC1,BC2 = d1$BC2,
                 BC3 = d1$BC3,BC4 = d1$BC4,BC5 = d1$BC5)   
m1.4 <- ulam(
  alist(
    Resolution ~ dbinom( 1 , p ) ,
    logit(p) <- a1[BC1] + a2[BC2] + a3[BC3] + a4[BC4] + a5[BC5],
    a1[BC1] ~ dnorm( 0 , 1),
    a2[BC2] ~ dnorm( 0 , 1),
    a3[BC3] ~ dnorm( 0 , 1),
    a4[BC4] ~ dnorm( 0 , 1),
    a5[BC5] ~ dnorm( 0 , 1)
    
  ) , data=dat_list_1 , chains=4 , log_lik=TRUE)

precis( m1.4 , depth=2 )
plot( precis( m1.4 , depth=2 ) )

post1 <- extract.samples(m1.4)
post_a <- inv_logit( post1$a2)
plot( precis( as.data.frame(post_a) ))
'''

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
#Time for Markov, we call it using ulam.
m1.3 <- ulam(
  alist(
    Resolution ~ dbinom( 1 , p ) ,
    logit(p) <- a[CW] + b[BC] + VR*SVR+ Count*SBC,
    a[CW] ~ dnorm( 0 , 1),
    b[BC] ~ dnorm( 0 , 0.5),
    VR ~ dnorm( 0 , 0.5),
    Count ~ dnorm( 0 , 0.5)
  ) , data=dat_list , chains=4 , log_lik=TRUE)

#Check diagnostics.
precis( m1.3 , depth=2 )

#trankplots
trankplot(m1.3)
#traceplots
traceplot(m1.3)
#plot cw - caught where place or testing level where bug was detected 
post <- extract.samples(m1.3)
post_a <- inv_logit( post$a)
plot( precis( as.data.frame(post_a) ))

#plot bug completeness quality - treatments from 1-6 

post <- extract.samples(m1.3)
post_b <- inv_logit( post$b)
plot( precis( as.data.frame(post_b) ))

#plot SVR 
post <- extract.samples(m1.3)
post_vr <- inv_logit( post$VR)
plot( precis( as.data.frame(post_vr) ))

plot( precis(m1.3))
