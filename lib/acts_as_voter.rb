module ThumbsUp #:nodoc:
  module ActsAsVoter #:nodoc:

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def acts_as_voter

        # If a voting entity is deleted, keep the votes.
        # If you want to nullify (and keep the votes), you'll need to remove
        # the unique constraint on the [ voter, voteable ] index in the database.
        # has_many :votes, :as => :voter, :dependent => :nullify
        # Destroy votes when a user is deleted.
        has_many :votes, :as => :voter, :dependent => :destroy

        include ThumbsUp::ActsAsVoter::InstanceMethods
        extend  ThumbsUp::ActsAsVoter::SingletonMethods
      end
    end

    # This module contains class methods
    module SingletonMethods
    end

    # This module contains instance methods
    module InstanceMethods

      # Usage user.vote_count(:up)  # All +1 votes
      #       user.vote_count(:down) # All -1 votes
      #       user.vote_count()      # All votes

      def vote_count(for_or_against = :all, dimension = nil)
        v = Vote.where(:voter_id => id).where(:voter_type => self.class.name).by_dimension(dimension)
        v = case for_or_against
          when :all   then v
          when :up    then v.where(:vote => true)
          when :down  then v.where(:vote => false)
        end
        v.count
      end

      def voted_for?(voteable, dimension = nil)
        voted_which_way?(voteable, :up, dimension)
      end

      def voted_against?(voteable, dimension = nil)
        voted_which_way?(voteable, :down, dimension)
      end

      def voted_on?(voteable, dimension = nil)
        0 < Vote.where(
              :voter_id => self.id,
              :voter_type => self.class.name,
              :voteable_id => voteable.id,
              :voteable_type => voteable.class.name
            ).by_dimension(dimension).count
      end

      def vote_for(voteable, dimension = nil)
        self.vote(voteable, { :direction => :up, :exclusive => false, :dimension => dimension })
      end

      def vote_against(voteable, dimension = nil)
        self.vote(voteable, { :direction => :down, :exclusive => false, :dimension => dimension })
      end

      def vote_exclusively_for(voteable, dimension = nil)
        self.vote(voteable, { :direction => :up, :exclusive => true, :dimension => dimension })
      end

      def vote_exclusively_against(voteable, dimension = nil)
        self.vote(voteable, { :direction => :down, :exclusive => true, :dimension => dimension })
      end

      def vote(voteable, options = {})
        raise ArgumentError, "you must specify :up or :down in order to vote" unless options[:direction] && [:up, :down].include?(options[:direction].to_sym)
        if options[:exclusive]
          self.clear_votes(voteable, options[:dimension])
        end
        direction = (options[:direction].to_sym == :up)
        Vote.create!(:vote => direction, :voteable => voteable, :voter => self, :dimension => options[:dimension])
      end

      def clear_votes(voteable, dimension = nil)
        Vote.where(
          :voter_id => self.id,
          :voter_type => self.class.name,
          :voteable_id => voteable.id,
          :voteable_type => voteable.class.name
        ).by_dimension(dimension).map(&:destroy)
      end

      def voted_which_way?(voteable, direction, dimension = nil)
        raise ArgumentError, "expected :up or :down" unless [:up, :down].include?(direction)
        0 < Vote.where(
              :voter_id => self.id,
              :voter_type => self.class.name,
              :vote => direction == :up ? true : false,
              :voteable_id => voteable.id,
              :voteable_type => voteable.class.name
            ).by_dimension(dimension).count
      end

    end
  end
end