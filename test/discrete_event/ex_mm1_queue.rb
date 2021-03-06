require 'discrete_event'

module DiscreteEvent
  module Example
    #
    # A single-server queueing system with Markovian arrival and service
    # processes.
    #
    # Note that the simulation runs indefinitely, and that it doesn't collect
    # statistics; this is left to the user. See mm1_queue_demo, below, for
    # an example of how to collect statistics and how to stop the simulation
    # by throwing the :stop symbol.
    #
    class MM1Queue < DiscreteEvent::Simulation
      Customer = Struct.new(:arrival_time, :queue_on_arrival,
                            :service_begin, :service_end)

      attr_reader :arrival_rate, :service_rate, :system, :served

      def initialize arrival_rate, service_rate
        super()
        @arrival_rate, @service_rate = arrival_rate, service_rate
        @system = []
        @served = []
      end

      # Sample from Exponential distribution with given mean rate.
      def rand_exp rate
        -Math::log(rand)/rate
      end

      # Customer arrival process.
      # The after method is provided by {DiscreteEvent::Simulation}.
      # The given action (a Ruby block) will run after the random delay
      # computed by rand_exp. When it runs, the last thing the action does is
      # call new_customer, which creates an event for the next customer.
      def new_customer
        after rand_exp(arrival_rate) do
          system << Customer.new(now, queue_length)
          serve_customer if system.size == 1
          new_customer
        end
      end

      # Customer service process.
      def serve_customer
        system.first.service_begin = now
        after rand_exp(service_rate) do
          system.first.service_end = now
          served << system.shift
          serve_customer unless system.empty?
        end
      end

      # Number of customers currently waiting for service (does not include
      # the one (if any) currently being served).
      def queue_length
        if system.empty? then 0 else system.length - 1 end
      end

      # Called by super.run.
      def start
        new_customer
      end
    end

    #
    # Run until a fixed number of passengers has been served.
    #
    def mm1_queue_demo arrival_rate, service_rate, num_pax
      # Run simulation and accumulate stats.
      q = MM1Queue.new arrival_rate, service_rate
      num_served = 0
      total_queue = 0.0
      total_wait = 0.0
      q.run do
        unless q.served.empty?
          raise "confused" if q.served.size > 1
          c = q.served.shift
          total_queue += c.queue_on_arrival
          total_wait  += c.service_begin - c.arrival_time
          num_served  += 1
        end
        throw :stop if num_served >= num_pax
      end

      # Use standard formulas for comparison.
      rho = arrival_rate / service_rate
      expected_mean_wait = rho / (service_rate - arrival_rate)
      expected_mean_queue = arrival_rate * expected_mean_wait

      return total_queue / num_served, expected_mean_queue,
             total_wait  / num_served, expected_mean_wait
    end
  end
end

