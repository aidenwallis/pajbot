import logging
from contextlib import contextmanager

from sqlalchemy import create_engine
from sqlalchemy import event
from sqlalchemy import exc
from sqlalchemy import inspect
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import scoped_session
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import Pool

Base = declarative_base()

log = logging.getLogger("pajbot")


@event.listens_for(Pool, "checkout")
def check_connection(dbapi_con, _con_record, _con_proxy):
    """
    Listener for Pool checkout events that pings every connection before using.
    Implements pessimistic disconnect handling strategy. See also:
    http://docs.sqlalchemy.org/en/rel_0_8/core/pooling.html#disconnect-handling-pessimistic
    """

    cursor = dbapi_con.cursor()
    try:
        cursor.execute("SELECT 1")
    except exc.OperationalError as ex:
        if ex.args[0] in (
            2006,  # MySQL server has gone away
            2013,  # Lost connection to MySQL server during query
            2055,
        ):  # Lost connection to MySQL server at '%s', system error: %d
            # caught by pool, which will retry with a new connection
            raise exc.DisconnectionError()

        # Raise the normal operational error exception
        raise


class ServerNoticeLogger:
    def append(self, notice):
        # notice is stripped of whitespace since it usually ends in a newline
        # These are notices like "NOTICE:  relation "schema_version" already exists, skipping",
        # but they can also be warnings, etc.
        log.info(f"PostgreSQL Server notice: {notice.strip()}")


class DBManager:
    engine = None
    Session = None
    ScopedSession = None

    @staticmethod
    def init(url):
        DBManager.engine = create_engine(url, pool_pre_ping=True, pool_size=10, max_overflow=20)

        # https://docs.sqlalchemy.org/en/13/core/events.html#sqlalchemy.events.PoolEvents.connect
        @event.listens_for(DBManager.engine, "connect")
        def on_connect(dbapi_connection, connection_record):
            # http://initd.org/psycopg/docs/connection.html#connection.notices
            # > The notices attribute is writable: the user may replace it with any Python object
            # > exposing an append() method. If appending raises an exception the notice is silently dropped.
            # This replaces the list object with a logger that logs the incoming notices
            dbapi_connection.notices = ServerNoticeLogger()

        DBManager.Session = sessionmaker(bind=DBManager.engine, autoflush=False)
        DBManager.ScopedSession = scoped_session(sessionmaker(bind=DBManager.engine))

    @staticmethod
    def create_session(**options):
        """
        Useful options:
        expire_on_commit=False
        """

        try:
            return DBManager.Session(**options)
        except:
            log.exception("Unhandled exception while creating a session")

        return None

    @staticmethod
    def create_scoped_session(**options):
        """
        Useful options:
        expire_on_commit=False
        """

        try:
            return DBManager.ScopedSession(**options)
        except:
            log.exception("Unhandled exception while creating a scoped session")

        return None

    @staticmethod
    def session_add_expunge(db_object, **options):
        """
        Useful shorthand method of creating a session,
        adding an object to the session,
        committing,
        expunging the object,
        closing the session,
        all while having expire_on_commit set to False
        """

        if "expire_on_commit" not in options:
            options["expire_on_commit"] = False

        session = DBManager.create_session(**options)
        try:
            session.add(db_object)
            session.commit()
            session.expunge(db_object)
        except:
            session.rollback()
            raise
        finally:
            session.close()

    @staticmethod
    @contextmanager
    def create_session_scope(**options):
        session = DBManager.create_session(**options)
        try:
            yield session
            session.commit()
        except:
            session.rollback()
            raise
        finally:
            session.close()

    @staticmethod
    @contextmanager
    def create_session_scope_nc(**options):
        session = DBManager.create_session(**options)
        try:
            yield session
        except:
            session.rollback()
            raise
        finally:
            session.close()

    @staticmethod
    @contextmanager
    def create_session_scope_ea(**options):
        session = DBManager.create_session(**options)
        try:
            yield session
            session.expunge_all()
        except:
            session.rollback()
            raise
        finally:
            session.close()

    @staticmethod
    @contextmanager
    def create_scoped_session_scope(**options):
        session = DBManager.create_scoped_session(**options)
        try:
            yield session
            session.commit()
        except:
            session.rollback()
            raise
        finally:
            session.close()

    @staticmethod
    def debug(raw_object):
        try:
            inspected_object = inspect(raw_object)
            log.debug(f"Object:     {raw_object}")
            log.debug(f"Transient:  {inspected_object.transient}")
            log.debug(f"Pending:    {inspected_object.pending}")
            log.debug(f"Persistent: {inspected_object.persistent}")
            log.debug(f"Detached:   {inspected_object.detached}")
        except:
            log.exception("Uncaught exception in DBManager.debug")
