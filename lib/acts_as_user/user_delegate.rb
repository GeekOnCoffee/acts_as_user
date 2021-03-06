module ActsAsUser
  module UserDelegate
    def self.included(base)
      options = base.class_variable_get('@@acts_as_user_options')
      if !!options[:has_many]
        base.has_many :users, :as => :userable, :dependent => :destroy, :autosave => true
        base.alias_method_chain :users, :autobuild
        base.accepts_nested_attributes_for :users, :allow_destroy => true
      else
        base.has_one :user, :as => :userable, :dependent => :destroy, :autosave => true
        base.alias_method_chain :user, :autobuild
        base.validate :user_must_be_valid
        base.extend ClassMethods
        base.define_user_accessors
      end
    end

    def user_with_autobuild
      user_without_autobuild || build_user
    end

    def users_with_autobuild
      users_without_autobuild.present? ? users_without_autobuild : (users_without_autobuild << User.new)
    end

    def method_missing(meth, *args, &blk)
      user.send(meth, *args, &blk)
    rescue NoMethodError
      super
    end

    def deep_inspect
      "#{self.inspect} -- #{self.user.inspect}"
    end

    protected

    def user_must_be_valid
      unless user.valid?
        user.errors.each do |attr, message|
          errors.add(attr, message)
        end
      end
    end

    module ClassMethods

      def define_user_accessors
        #We check the user columns to declare them as attributes to delegate
        all_attributes = User.columns.map(&:name)

        attributes_to_delegate = all_attributes - ActsAsUser.ignored_attributes

        #User method delegation
        attributes_to_delegate.each do |attrib|
          class_eval <<-RUBY
          def #{attrib}
            user.#{attrib}
          end

          def #{attrib}=(value)
            self.user.#{attrib} = value
          end

          def #{attrib}?
            self.user.#{attrib}?
          end
            RUBY
        end
      end
    end
  end
end
