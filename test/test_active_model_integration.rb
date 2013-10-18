# Author:: Couchbase <info@couchbase.com>
# Copyright:: 2011, 2012 Couchbase, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require File.join(File.dirname(__FILE__), 'setup')

class ActiveUser < Couchbase::Model
  attribute :name
  attribute :email
  attribute :role
  attribute :created_at, :updated_at, default: -> { Time.now.utc }

  validates_presence_of :email
  validates :role, presence: true, inclusion: { in: %w(admin editor) }

  before_create :upcase_name

  private

  def upcase_name
    self.name = self.name.upcase unless self.name.nil?
  end
end

class ActiveObj < Couchbase::Model
end

class TestActiveModelIntegration < MiniTest::Unit::TestCase

  include ActiveModel::Lint::Tests

  def setup
    @model = ActiveUser.new # used by ActiveModel::Lint::Tests
    @mock = start_mock
    bucket = Couchbase.connect(:hostname => @mock.host, :port => @mock.port)
    ActiveUser.bucket = bucket
  end

  def teardown
    stop_mock(@mock)
  end

  def test_active_model_includes
    [ActiveModel::Conversion, ActiveModel::Validations, ActiveModel::Validations::HelperMethods].each do |mod|
      assert ActiveUser.ancestors.include?(mod), "Model not including #{mod}"
    end
  end

  def test_active_model_validations
    no_role   = ActiveUser.new(email: 'joe@example.com', role: nil)
    bad_role  = ActiveUser.new(email: 'joe@example.com', role: 'bad')
    good_role = ActiveUser.new(email: 'joe@example.com', role: 'admin')

    refute no_role.valid?
    refute bad_role.valid?
    assert good_role.valid?
  end

  def test_active_model_validation_helpers
    valid   = ActiveUser.new(email: 'joe@example.com', role: 'editor')
    invalid = ActiveUser.new(name: 'Joe', role: 'editor')

    assert valid.valid?
    refute invalid.valid?
  end

  def test_before_save_callback
    assert user = ActiveUser.create(name: 'joe', role: 'admin', email: 'joe@example.com')
    assert_equal 'JOE', user.name
  end

  def test_model_name_exposes_singular_and_human_name
    assert_equal 'active_user', @model.class.model_name.singular
    assert_equal 'Active user', @model.class.model_name.human
  end

  def test_model_equality
    obj1 = ActiveObj.create
    obj2 = ActiveObj.find(obj1.id)

    assert_equal obj1, obj2
  end

  def test_to_key
    assert_equal ['the-id'], ActiveObj.new(:id => 'the-id').to_key
    assert_equal ['the-key'], ActiveObj.new(:key => 'the-key').to_key
  end

  def test_to_param
    assert_equal 'the-id', ActiveObj.new(:id => 'the-id').to_param
    assert_equal 'the-key', ActiveObj.new(:key => ['the', 'key']).to_param
  end

end
