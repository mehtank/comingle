import React, {useState, useMemo} from 'react'
import useInterval from '@use-it/interval'
import {Link, useParams, useHistory} from 'react-router-dom'
import {Accordion, Alert, Button, ButtonGroup, Card, Dropdown, DropdownButton, ListGroup, SplitButton, Tooltip, OverlayTrigger} from 'react-bootstrap'
import {useTracker} from 'meteor/react-meteor-data'
import {FontAwesomeIcon} from '@fortawesome/react-fontawesome'
import {faUser, faHandPaper, faSortAlphaDown, faSortAlphaDownAlt} from '@fortawesome/free-solid-svg-icons'

import {Rooms, roomWithTemplate} from '/lib/rooms'
import {Presence} from '/lib/presence'
import {Loading} from './Loading'
import {Header} from './Header'
import {Name} from './Name'
import {CardToggle} from './CardToggle'
import {capitalize} from './lib/capitalize'
import {getPresenceId, getCreator} from './lib/presenceId'
import {formatTimeDelta} from './lib/dates'
import {sortByKey, titleKey, sortNames, uniqCountNames} from '/lib/sort'

findMyPresence = (presence) ->
  presenceId = getPresenceId()
  presence?.find (p) -> p.id == presenceId

export RoomList = ({loading}) ->
  {meetingId} = useParams()
  [sortKey, setSortKey] = useState 'title'
  [reverse, setReverse] = useState false
  rooms = useTracker -> Rooms.find(meeting: meetingId).fetch()
  presences = useTracker -> Presence.find(meeting: meetingId).fetch()
  presenceByRoom = useMemo ->
    byRoom = {}
    for presence in presences
      for type in ['visible', 'invisible']
        for room in presence.rooms[type]
          byRoom[room] ?= []
          byRoom[room].push
            type: type
            name: presence.name
            id: presence.id
    byRoom
  , [presences]
  sortedRooms = useMemo ->
    sorted = sortByKey rooms[..],
      if sortKey == 'participants'
        (room) ->
          titleKey "#{presenceByRoom[room._id]?.length ? 0}.#{room.title}"
      else
        sortKey
    sorted.reverse() if reverse
    sorted
  , [rooms, sortKey, reverse, if sortKey == 'participants' then presenceByRoom]
  Sublist = ({heading, filter, startClosed}) ->
    subrooms = sortedRooms.filter filter
    return null unless subrooms.length
    <Accordion defaultActiveKey={unless startClosed then "0"}>
      <Card>
        <CardToggle eventKey="0">
          {heading}
        </CardToggle>
        <Accordion.Collapse eventKey="0">
          <Card.Body>
            <ListGroup>
              {for room in subrooms
                <RoomInfo key={room._id} room={room}
                 presence={presenceByRoom[room._id]}/>
              }
              {if loading
                <Loading/>
              }
            </ListGroup>
          </Card.Body>
        </Accordion.Collapse>
      </Card>
    </Accordion>
  <div className="d-flex flex-column h-100">
    <div className="RoomList flex-shrink-1 overflow-auto">
      <Header/>
      <Name/>
      {unless rooms.length or loading
        <Alert variant="warning">
          No rooms in this meeting.
        </Alert>
      }
      <Sublist heading="Rooms You're In:"
       filter={(room) -> findMyPresence presenceByRoom[room._id]}/>
      <Sublist heading="Other Rooms:"
       filter={(room) -> not findMyPresence presenceByRoom[room._id]}/>
      <Sublist heading="Archived Rooms:" startClosed
       filter={(room) -> room.archived}/>
      {if rooms.length > 1
        <ButtonGroup className="sorting my-3 w-100 text-center">
          <DropdownButton title="Sort By">
            {for key in ['title', 'created', 'participants']
              <Dropdown.Item key={key} active={key == sortKey}
               onClick={do (key) -> (e) -> setSortKey key}>
                {capitalize key}
              </Dropdown.Item>
            }
          </DropdownButton>
          <OverlayTrigger placement="top" overlay={(props) ->
            <Tooltip {...props}>
              Currently sorting in {
                if reverse
                  <b>decreasing</b>
                else
                  <b>increasing</b>
              } order. <br/>
              Select to toggle.
            </Tooltip>
          }>
            <Button variant="secondary" onClick={(e) -> setReverse not reverse}>
              {if reverse
                 <FontAwesomeIcon aria-label="Decreasing Order"
                  icon={faSortAlphaDownAlt}/>
               else
                 <FontAwesomeIcon aria-label="Increasing Order"
                  icon={faSortAlphaDown}/>
              }
            </Button>
          </OverlayTrigger>
        </ButtonGroup>
      }
    </div>
    <RoomNew/>
  </div>

export RoomInfo = ({room, presence}) ->
  {meetingId} = useParams()
  if presence?
    myPresence = findMyPresence presence
    clusters = sortNames presence, (p) -> p.name
    clusters = uniqCountNames presence, (p) -> p.name
  myPresenceClass = if myPresence then "room-info-#{myPresence.type}" else ""
  <Link to="/m/#{meetingId}##{room._id}" className="list-group-item list-group-item-action room-info #{myPresenceClass}">
    {if myPresence or room.raised
      help = "#{if room.raised then 'Lower' else 'Raise'} Hand"
      toggleHand = ->
        Meteor.call 'roomEdit',
          id: room._id
          raised: not room.raised
          updator: getCreator()
      <div className="raise-hand #{if room.raised then 'active' else ''}"
       aria-label={help}>
        <OverlayTrigger placement="top" overlay={(props) ->
          <Tooltip {...props}>{help}</Tooltip>
        }>
          <FontAwesomeIcon aria-label={help} icon={faHandPaper}
           onClick={toggleHand}/>
        </OverlayTrigger>
        {if room.raised and typeof room.raised != 'boolean'
          [timer, setTimer] = useState formatTimeDelta (new Date) - room.raised
          useInterval ->
            setTimer formatTimeDelta (new Date) - room.raised
          , 1000
          <div className="timer">
            {timer}
          </div>
        }
      </div>
    }
    <span className="title">{room.title}</span>
    {if clusters?.length
      <div className="presence">
        {for person in clusters
          <span key={person.item.id} className="presence-#{person.item.type}">
            <FontAwesomeIcon icon={faUser} className="mr-1"/>
            {person.name}
            {if person.count > 1
              <span className="ml-1 badge badge-secondary">{person.count}</span>
            }
          </span>
        }
      </div>
    }
  </Link>

export RoomNew = ->
  {meetingId} = useParams()
  [title, setTitle] = useState ''
  history = useHistory()
  submit = (e) ->
    e.preventDefault?()
    return unless title.trim().length
    room =
      meeting: meetingId
      title: title.trim()
      creator: getCreator()
      template: e.template ? 'jitsi'
    setTitle ''
    roomId = await roomWithTemplate room
    history.push "/m/#{meetingId}##{roomId}"
  <form onSubmit={submit}>
    <div className="form-group">
      <input type="text" placeholder="Title" className="form-control"
       value={title} onChange={(e) -> setTitle e.target.value}/>
      <SplitButton type="submit" className="btn-block" drop="up"
                   title="Create Room">
        <Dropdown.Item onClick={-> submit template: ''}>
          Empty room
        </Dropdown.Item>
        <Dropdown.Item onClick={-> submit template: 'jitsi'}>
          Jitsi (default)
        </Dropdown.Item>
        <Dropdown.Item onClick={-> submit template: 'jitsi+cocreate'}>
          Jitsi + Cocreate
        </Dropdown.Item>
      </SplitButton>
    </div>
  </form>
