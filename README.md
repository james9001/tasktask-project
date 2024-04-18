# tasktask-project
This is the main repository for "tasktask", named as such because it was created for a coding task about.. tasks!

## Instructions
- Clone this repository locally.
- If you are on macOS or Linux and have Docker Desktop or Docker Engine installed, you should be able to just run `./setup.sh`. I'm assuming your installation isn't rootless, so you may need to enter your sudo password. If some part of the script fails, open it up and the comments will explain what it is doing, in case you need to do something manually.
- After the script finishes running and the containers have had a little bit of time to start, open `http://localhost:8092` in your browser and you'll see the TaskTask frontend.
- If you'd like some test data, I have included a Postman collection in this repository you can use to easily set some up.

## The design
The "tasktask" system consists of three repositories arranged in a "microservices"/"many-repo" pattern:
- `tasktask-project`, this repo, which contains the automated setup script and docker compose configuration
- `tasktask-backend`, a Node/Express microservice which uses a Postgres container as its data store, and Prisma ORM to manage the database schema and the backend's interaction with it
- `tasktask-frontend`, a frontend project which consists of a (relatively) lightweight Ionic Framework project (as lightweight as Ionic can realistically be), the static assets of which are built into a simple nginx container

The tech stack is largely aligned with the one described in the task document, with the exception of React (also, no Golang, as there isn't a need for a third service here). Although I've had a fair bit of experience working with NextJS, that's largely from a backend/DevOps point of view - not much hands-on time with React. That means things like converting the NextJS deployments over to custom Express servers, to optimise a Kubernetes self-hosting situation. Fun fact: Automatic Static Optimisation still works with a custom Express-based server, contrary to what the docs state.

While I am confident in my ability to pick up new technologies quickly, this task was already highly time constrained, and so React had to take a back seat. Therefore, I chose something I'm more familiar with - Ionic Framework - even though in many respects it is less appealing to me from a purely technical perspective. Nginx, as well - I've never been able to find a way to get decent Prometheus metrics out of it without significant fiddling. The Nginx container serving almost entirely static assets (with one exception, the environment configuration file `web-config.js` I set up) means that it's straightforward to set up caching at the edge or load balancer level. This is also very doable with NextJS, but it requires a more careful approach, in my experience.

CICD was a priority for this task - I'm fond of using pre-commit as a way to both interrogate things as I'm writing code, AND as a heavy static analysis pipeline inside the Docker multistage builds. Multistage builds are great for keeping concerns separate, for parallelism (really speeds things up), and often you'll get speedups from layer caching (unexpected layer caching can, however, be a double edged sword).

## Assumptions and thoughts (particularly date/time related)
- It isn't specified whether the date fields in the Task model should be just date, date/time, and how they are intended to behave with timezones. Naturally, as soon as you have more than one timezone in your business, the confusion begins. This is especially unfortunate because pure date types are much more pleasant to work with. As a result I've made the assumption that we want and/or are okay with full date/time. To try to avoid issues with timezones in the backend, and questions like "which timezone is the server on?", I went with a timestamp approach in Postgres and the Express router layer.
  - The Postgres data type of BigInt was a must for this, as the regular Int would limit us to timestamps ending in 2038.
  - Prisma integrates the Postgres BigInt as the ES2020 `BigInt` (or `bigint`), which required some tweaking throughout the stack to get it to behave properly (such as setting lib targets to es2020, and a polyfill to get the fields serialising properly)
  - Timestamp support in the Ionic layer doesn't really exist, which unfortunately resulted in having to map data models between frontend and backend types
- I also assumed that the application might naturally move beyond one business model type in future, and so built the frontend components in a way that could be flexibly reused to new types

## Addressing the risk
The scalability of the system was identified as a key risk, as the expected volume of data entities is in the range of tens of thousands. There are two strategies of note which will alleviate this risk:
- A paginated search query approach to retrieve data from the backend has been implemented. This is much more efficient than naively loading all existing data models from the database in the backend; with a more precise set of data being returned by default, the load on the system will be a lot lower than it might otherwise be. This paginated query approach also lends itself well to the functionality that'll be needed to address the "Should Have" user stories, as the select clause can simply be slightly amended.
- Secondly, instead of a sequential identifier autogenerated at the database layer, the ID/primary key of the Task data model is generated by the backend application. A UUID is mathematically (almost) guaranteed to be unique. Being generated by the application means that there is no risk of contention caused by serialised access at the database layer. Although it is possible to scale databases horizontally to a degree, it is far simpler to scale applications horizontally.

## The "should haves"
There are two "user stories" which are considered "should have" and thus are planned for in the near future:
- User should be able to sort by due date or create date
- User should be able to search based on task name
As mentioned above, the paginated search query approach futureproofs us for these requirements. Additional criteria will be added to the paginated search query to allow both filtering and sorting; the filtering and sorting elements of the criteria will be translated into adjustments to the select clause that the backend is using to retrieve data via Prisma. See this link for more info: `https://www.prisma.io/docs/orm/prisma-client/queries/filtering-and-sorting#sorting`

## If time wasn't a constraint
- Firstly, more testing. Way more testing, even if most of the unit testing feels like just checking the plumbing as opposed to verifying algorithmic correctness
- Playwright is something I want to get back into, in particular
- Load testing: it would be interesting to compare the paginated search approach with a more naieve "get all data" approach. My current load testing tool of choice is Gatling
- Validation of requests and data models. Currently returning HTTP 500 for bad input feels unfortunate. Previously I've done some error type checking in an Express error handler middleware to get some of this for "free" (contrast that with validating every property on every incoming request body)
- Some naming of components in the frontend repo isn't ideal
- More ESLint configuration: angular-eslint, specific rules (I'd really like a rule that flags if you're using non-arrow-syntax functions)

## Other points of interest
- No NestJS as a specific requirement is amusing, I've sometimes wondered what it really does for you - having peered over the fence into what some Node backend colleagues were working with
- It seems Express is getting better support for async method error control flow in 5.x, but until then it seems we are stuck having to set up try/catch clauses on all async routes
