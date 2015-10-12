# encoding: utf-8
require 'test_helper'

class TicketSelectorTest < ActiveSupport::TestCase

  # create base
  group = Group.create_or_update(
    name: 'SelectorTest',
    updated_at: '2015-02-05 16:37:00',
    updated_by_id: 1,
    created_by_id: 1,
  )
  roles  = Role.where( name: 'Agent' )
  agent1 = User.create_or_update(
    login: 'ticket-selector-agent1@example.com',
    firstname: 'Notification',
    lastname: 'Agent1',
    email: 'ticket-selector-agent1@example.com',
    password: 'agentpw',
    active: true,
    roles: roles,
    groups: [group],
    updated_at: '2015-02-05 16:37:00',
    updated_by_id: 1,
    created_by_id: 1,
  )
  agent2 = User.create_or_update(
    login: 'ticket-selector-agent2@example.com',
    firstname: 'Notification',
    lastname: 'Agent2',
    email: 'ticket-selector-agent2@example.com',
    password: 'agentpw',
    active: true,
    roles: roles,
    #groups: groups,
    updated_at: '2015-02-05 16:38:00',
    updated_by_id: 1,
    created_by_id: 1,
  )
  roles  = Role.where( name: 'Customer' )
  organization1 = Organization.create_if_not_exists(
    name: 'Selector Org',
    updated_at: '2015-02-05 16:37:00',
    updated_by_id: 1,
    created_by_id: 1,
  )
  customer1 = User.create_or_update(
    login: 'ticket-selector-customer1@example.com',
    firstname: 'Notification',
    lastname: 'Customer1',
    email: 'ticket-selector-customer1@example.com',
    password: 'customerpw',
    active: true,
    organization_id: organization1.id,
    roles: roles,
    updated_at: '2015-02-05 16:37:00',
    updated_by_id: 1,
    created_by_id: 1,
  )
  customer2 = User.create_or_update(
    login: 'ticket-selector-customer2@example.com',
    firstname: 'Notification',
    lastname: 'Customer2',
    email: 'ticket-selector-customer2@example.com',
    password: 'customerpw',
    active: true,
    organization_id: nil,
    roles: roles,
    updated_at: '2015-02-05 16:37:00',
    updated_by_id: 1,
    created_by_id: 1,
  )

  Ticket.where(group_id: group.id).destroy_all

  test 'ticket create' do

    ticket1 = Ticket.create(
      title: 'some title1',
      group: group,
      customer_id: customer1.id,
      owner_id: agent1.id,
      state: Ticket::State.lookup( name: 'new' ),
      priority: Ticket::Priority.lookup( name: '2 normal' ),
      created_at: '2015-02-05 16:37:00',
      #updated_at: '2015-02-05 17:37:00',
      updated_by_id: 1,
      created_by_id: 1,
    )
    assert( ticket1, 'ticket created' )
    assert_equal( ticket1.customer.id, customer1.id )
    assert_equal( ticket1.organization.id, organization1.id )
    sleep 1

    ticket2 = Ticket.create(
      title: 'some title2',
      group: group,
      customer_id: customer2.id,
      state: Ticket::State.lookup( name: 'new' ),
      priority: Ticket::Priority.lookup( name: '2 normal' ),
      created_at: '2015-02-05 16:37:00',
      #updated_at: '2015-02-05 17:37:00',
      updated_by_id: 1,
      created_by_id: 1,
    )
    assert( ticket2, 'ticket created' )
    assert_equal( ticket2.customer.id, customer2.id )
    assert_equal( ticket2.organization_id, nil )
    sleep 1

    # search not matching
    condition = {
      'ticket.state_id' => {
        operator: 'is',
        value: [99],
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 0 )

    # search matching
    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.state_id' => {
        operator: 'is',
        value: [Ticket::State.lookup( name: 'new' ).id],
      },
    }

    ticket_count, tickets = Ticket.selectors(condition, 10)
    assert_equal( ticket_count, 2 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 2 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 1 )

    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.state_id' => {
        operator: 'is not',
        value: [Ticket::State.lookup( name: 'open' ).id],
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10)
    assert_equal( ticket_count, 2 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 2 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 1 )

    # search - created_at
    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.created_at' => {
        operator: 'after (absolute)', # before (absolute)
        value: '2015-02-05T16:00:00.000Z',
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 2 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 1 )

    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.created_at' => {
        operator: 'after (absolute)', # before (absolute)
        value: '2015-02-05T18:00:00.000Z',
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 0 )

    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.created_at' => {
        operator: 'before (absolute)',
        value: '2015-02-05T18:00:00.000Z',
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 2 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 1 )

    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.created_at' => {
        operator: 'before (absolute)',
        value: '2015-02-05T16:00:00.000Z',
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 0 )

    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.created_at' => {
        operator: 'before (relative)',
        range: 'day', # minute|hour|day|month|
        value: '10',
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 2 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 1 )

    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.created_at' => {
        operator: 'within next (relative)',
        range: 'year', # minute|hour|day|month|
        value: '10',
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 0 )

    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.created_at' => {
        operator: 'within last (relative)',
        range: 'year', # minute|hour|day|month|
        value: '10',
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 2 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 1 )

    # search - updated_at
    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.updated_at' => {
        operator: 'before (absolute)',
        value: (Time.zone.now + 1.day).iso8601,
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 2 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 1 )

    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.updated_at' => {
        operator: 'before (absolute)',
        value: (Time.zone.now - 1.day).iso8601,
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 0 )

    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.updated_at' => {
        operator: 'after (absolute)',
        value: (Time.zone.now + 1.day).iso8601,
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 0 )

    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.updated_at' => {
        operator: 'after (absolute)',
        value: (Time.zone.now - 1.day).iso8601,
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 2 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 1 )

    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.updated_at' => {
        operator: 'before (relative)',
        range: 'day', # minute|hour|day|month|
        value: '10',
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 0 )

    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.updated_at' => {
        operator: 'within next (relative)',
        range: 'year', # minute|hour|day|month|
        value: '10',
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 0 )

    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'ticket.updated_at' => {
        operator: 'within last (relative)',
        range: 'year', # minute|hour|day|month|
        value: '10',
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 2 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 1 )

    # invalid conditions
    assert_raise RuntimeError do
      ticket_count, tickets = Ticket.selectors(nil, 10)
    end

    # search with customers
    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'customer.email' => {
        operator: 'contains',
        value: 'ticket-selector-customer1',
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 0 )

    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'customer.email' => {
        operator: 'contains not',
        value: 'ticket-selector-customer1-not_existing',
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 2 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 1 )

    # search with organizations
    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'organization.name' => {
        operator: 'contains',
        value: 'selector',
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 0 )

    # search with organizations
    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'organization.name' => {
        operator: 'contains',
        value: 'selector',
      },
      'customer.email' => {
        operator: 'contains',
        value: 'ticket-selector-customer1',
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 1 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 0 )

    condition = {
      'ticket.group_id' => {
        operator: 'is',
        value: group.id,
      },
      'organization.name' => {
        operator: 'contains',
        value: 'selector',
      },
      'customer.email' => {
        operator: 'contains not',
        value: 'ticket-selector-customer1',
      },
    }
    ticket_count, tickets = Ticket.selectors(condition, 10, agent1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, agent2)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer1)
    assert_equal( ticket_count, 0 )

    ticket_count, tickets = Ticket.selectors(condition, 10, customer2)
    assert_equal( ticket_count, 0 )

  end

end