import React from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import AuthProvider from './components/AuthProvider.jsx';
import ProtectedRoute from './components/ProtectedRoute.jsx';
import Login from './pages/Login.jsx';
import { StudentLayout, StudentDashboard, BookBus, MyBookings, BookingDetails, Complaints, ComplaintDetails } from './pages/Member2.jsx';
export default function App() {
  return <BrowserRouter><AuthProvider><Routes>
    <Route path="/login" element={<Login />} />
    <Route element={<ProtectedRoute />}><Route element={<StudentLayout />}>
      <Route path="/" element={<StudentDashboard />} />
      <Route path="/book" element={<BookBus />} />
      <Route path="/bookings" element={<MyBookings />} />
      <Route path="/bookings/:id" element={<BookingDetails />} />
      <Route path="/complaints" element={<Complaints />} />
      <Route path="/complaints/:id" element={<ComplaintDetails />} />
    </Route></Route>
    <Route path="*" element={<Navigate to="/" replace />} />
  </Routes></AuthProvider></BrowserRouter>;
}
