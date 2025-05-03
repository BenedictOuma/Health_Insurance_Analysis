create database Social_Health_Insurance;

use Social_Health_Insurance;

--------------------------------------------------------------------------creating foreign keys------------------------------------------------------------------------------

alter table Contributions
add constraint fk_MemberContribution
foreign key (member_id)
references Members(member_id);

alter table Healthcare_Services
add constraint fk_MemberService
foreign key (member_id)
references Members(member_id);

alter table Healthcare_Services
add constraint fk_ProviderService
foreign key (provider_id)
references Providers(provider_id);

alter table Surveys
add constraint fk_MemberSurvey
foreign key (member_id)
references Members(member_id);

alter table Claims
add constraint fk_ProviderClaim
foreign key (provider_id)
references Providers(provider_id);

alter table Claims
add constraint fk_ServiceClaim
foreign key (service_id)
references Healthcare_Services(service_id);

----------PROJECT QUESTIONS----------
-----------------------------------------------------------------------------------1.1---------------------------------------------------------------------------------------

with IncomeEmploymentDistribution as (
select
    income_level,
    employment_status,
    count(*) as member_count
from Members
where income_level in ('high', 'middle', 'low') and employment_status in ('Employed', 'Unemployed', 'Self-Employed')
group by income_level, employment_status
)
select
	income_level,
	employment_status,
	member_count,
rank() over (partition by income_level order by member_count desc) as rank_within_income
from IncomeEmploymentDistribution
order by income_level, rank_within_income;

-----------------------------------------------------------------------------------1.2---------------------------------------------------------------------------------------

select 
    region,
    case when is_subsidized = 1 then 'Subsidized'
	else 'Non-Subsidized'
    end as subsidy_status,
    count(member_id) as member_count
from Members
group by region, is_subsidized
order by region, subsidy_status;

-----------------------------------------------------------------------------------1.3---------------------------------------------------------------------------------------

with AgeByRegion as (
select 
    region,
    age
from Members
)
select 
region,
cast(avg(age) as decimal (10,2)) as average_age
from AgeByRegion
group by region;

-----------------------------------------------------------------------------------2.1---------------------------------------------------------------------------------------
----using temp table

select
    format(contribution_date, 'MM') as Month,
    sum(contribution_amount) as total_contributions
into #MonthlyContributions
from Contributions
group by format(contribution_date, 'MM');

select*from #MonthlyContributions
order by Month;

---using cte

with MonthlyContributions as (
select
    format(contribution_date, 'MM') as Month,
    sum(contribution_amount) as total_contributions
from Contributions
group by format(contribution_date, 'MM')
)
select*from MonthlyContributions
order by Month;

-----------------------------------------------------------------------------------2.2---------------------------------------------------------------------------------------

select 
    c.member_id,
	m.full_name,
    sum (c.penalty_applied) as TotalPenalty
from Contributions c
join Members m
on c.member_id = m.member_id
where c.penalty_applied > 100
group by c.member_id, m.full_name
order by TotalPenalty desc;

-----------------------------------------------------------------------------------2.3---------------------------------------------------------------------------------------

select top 5
    employer_id,
    sum(contribution_amount) as total_contributed
from contributions
group by employer_id
order by total_contributed desc;

-----------------------------------------------------------------------------------3.1---------------------------------------------------------------------------------------

select 
    service_type,
    count(*) as service_count
from healthcare_services
group by service_type
order by service_count desc;

-----------------------------------------------------------------------------------3.2---------------------------------------------------------------------------------------
---how health facilities (providers) from different regions impact out-of-pocket expenses

select
    h.service_type,
    p.region,
    avg(h.out_of_pocket) as avg_out_of_pocket
from healthcare_services h
join providers p
on h.provider_id = p.provider_id
group by h.service_type, p.region
order by avg_out_of_pocket desc;

---how people (members) from different regions experience costs

select 
    h.service_type,
    m.region as member_region,
    avg(h.out_of_pocket) as avg_out_of_pocket
from healthcare_services h
join members m on h.member_id = m.member_id
group by h.service_type, m.region
order by avg_out_of_pocket;

-----------------------------------------------------------------------------------3.3---------------------------------------------------------------------------------------
---using top 10

select top 10
    member_id,
    cost_total,
    cost_covered
from Healthcare_Services
where cost_covered < 0.51 * cost_total
order by cost_total desc;

---ranking all

select
    member_id,
    cost_total,
    cost_covered
from Healthcare_Services
where cost_covered < 0.51 * cost_total
order by cost_total desc;

---using subqueries

select top 10
    member_id,
    cost_total,
    cost_covered,
    percentage_coverage
from (
    select 
        member_id,
        cost_total,
        cost_covered,
        round(cost_covered * 100.0 /(cost_total),2) as percentage_coverage
    from Healthcare_Services
) as sub
where percentage_coverage < 51
order by cost_total desc;

-----------------------------------------------------------------------------------4.1---------------------------------------------------------------------------------------

select 
    provider_id,
    count(*) as services_offered
from healthcare_services
group by provider_id
order by services_offered desc;

-----------------------------------------------------------------------------------4.2---------------------------------------------------------------------------------------

with RecentProviders as (
select provider_id
from providers
where accreditation_date >= dateadd(year, -2, getdate())
),
ClaimStats as (
select 
    c.provider_id,
    c.claim_status,
    count(*) as claim_count
from claims c
join RecentProviders r
on c.provider_id = r.provider_id
group by c.provider_id, c.claim_status
)
select 
    provider_id,
    sum(case when claim_status = 'Approved' then claim_count else 0 end) as approved,
    sum(claim_count) as total,
    round(sum(case when claim_status = 'Approved' then claim_count else 0 end) * 100.0 / sum(claim_count), 2) as approval_rate
from ClaimStats
group by provider_id;

-----------------------------------------------------------------------------------5.1---------------------------------------------------------------------------------------

select 
    claim_status,
    sum(claim_amount) as total_claim_amount
from claims
group by claim_status
order by total_claim_amount desc;

-----------------------------------------------------------------------------------5.2---------------------------------------------------------------------------------------
---using != for not equal to

select 
    c.claim_id,
    h.service_id,
    c.claim_amount,
    h.cost_covered
from claims c
join healthcare_services h
on c.service_id = h.service_id
where c.claim_amount != h.cost_covered;

---using <> for not equal to

select 
    c.claim_id,
    h.service_id,
    c.claim_amount,
    h.cost_covered
from claims c
join healthcare_services h
on c.service_id = h.service_id
where c.claim_amount <> h.cost_covered;


-----------------------------------------------------------------------------------6.1---------------------------------------------------------------------------------------

select
    m.region,
    cast(avg(satisfaction_score) as decimal(5,2)) as avg_satisfaction
from surveys s
join members m
on s.member_id = m.member_id
group by m.region;

-----------------------------------------------------------------------------------6.2---------------------------------------------------------------------------------------
---using case when & subquery

select 
    trust_level,
    cast(avg(satisfaction_score) as decimal(5,2)) as avg_satisfaction
from (
select 
    satisfaction_score,
    case when trust_level = 'High' then 'High Trust' when trust_level = 'Medium' then 'Moderate Trust' else 'Low Trust'
    end as trust_level
from surveys
) as categorized
group by trust_level;

---without using case when & subquery

select
    trust_level,
    cast(avg(satisfaction_score) as decimal(5,2)) as avg_satisfaction
from surveys
group by trust_level;

-----------------------------------------------------------------------------------7.1---------------------------------------------------------------------------------------

select count(*) as pending_cases
from legal_cases
where status = 'Pending';

-----------------------------------------------------------------------------------7.2---------------------------------------------------------------------------------------

select
	case_id,
    impact_level,
    avg(datediff(day, filing_date, getdate())) as avg_days_since_filing
from legal_cases
group by case_id, impact_level;

----------ADVANCED CHALLANGES----------
----------------------------------------------------------------1. member healthcare utilization profile---------------------------------------------------------------------
---gives all members includint those whose total costs and satisfaction averages are null

select
    m.member_id,
    count(h.service_id) as num_services,
    avg(h.cost_total) as avg_total_cost,
    avg(s.satisfaction_score) as avg_satisfaction
from members m
left join healthcare_services h
on m.member_id = h.member_id
left join surveys s
on m.member_id = s.member_id
group by m.member_id;

---ensures no null values

select
    m.member_id,
    count(h.service_id) as num_services,
    avg(h.cost_total) as avg_total_cost,
    avg(s.satisfaction_score) as avg_satisfaction
from members m
join healthcare_services h
on m.member_id = h.member_id
join surveys s
on m.member_id = s.member_id
group by m.member_id;

---ensures no null values and same as one immediately above

select
    m.member_id,
    count(h.service_id) as num_services,
    avg(h.cost_total) as avg_total_cost,
    avg(s.satisfaction_score) as avg_satisfaction
from members m
inner join healthcare_services h
on m.member_id = h.member_id
inner join surveys s
on m.member_id = s.member_id
group by m.member_id;

-------------------------------------------------------------------------2. high penalty group-------------------------------------------------------------------------------

---using distinct

select distinct member_id, 'High Penalty' as risk_reason, avg(penalty_applied) as risk_value
from contributions
where penalty_applied > 100
group by member_id
union
select distinct member_id, 'Low Satisfaction' as risk_reason, avg(Satisfaction_score) as risk_value 
from surveys
where satisfaction_score < 3
group by member_id;

---without using distinct but same

select member_id, 'High Penalty' as risk_reason, avg(penalty_applied) as risk_value
from contributions
where penalty_applied > 100
group by member_id
union
select member_id, 'Low Satisfaction' as risk_reason, avg(Satisfaction_score) as risk_value 
from surveys
where satisfaction_score < 3
group by member_id;

---VISUALIZATION---
---1. Core Member & Financial Overview Dashboard (Merge of Demographics + Financials)
---a.)Pie Chart: Distribution of members by income level

select
	income_level,
	count(member_id) as Total_members
from Members
group by income_level
order by income_level desc;

---b.)Stacked Column Chart: Members by employment status or subsidy status across regions (choose one for simplicity)

select
employment_status,
is_subsidized as subsidy_status,
count(member_id) as Total_members
from Members
group by employment_status, is_subsidized
order by Total_members;

---c.)Line Chart with Moving Average: Monthly contributions with trend

select
    format(contribution_date, 'MM') as Month,
    sum(contribution_amount) as total_contributions
from Contributions
group by format(contribution_date, 'MM');

---d.)Gauge or Bar Chart: Actual vs. target contributions by month



--------------------------------------------------------------------------------end------------------------------------------------------------------------------------------

